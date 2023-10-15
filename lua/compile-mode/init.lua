---@alias CommandParam { args: string? }
---@alias Config { split_vertically: boolean?, no_baleia_support: boolean?, default_command: string? }

local a = require("plenary.async")
---@diagnostic disable-next-line: undefined-field
local buf_set_opt = vim.api.nvim_buf_set_option

local M = {}

---@type string|nil
M.prev_command = nil
---@type Config
M.config = {}

---@type fun(opts: table): string
local input = a.wrap(vim.ui.input, 2)

---@type fun(cmd: string[]): string[], integer
local runjob = a.wrap(function(cmd, callback)
	local result = {}

	vim.fn.jobstart(cmd, {
		stdout_buffered = true,
		stderr_buffered = true,
		on_stdout = function(_, data)
			if data then
				vim.list_extend(result, data)
			end
		end,
		on_stderr = function(_, data)
			if data then
				vim.list_extend(result, data)
			end
		end,
		on_exit = function(_, code)
			table.remove(result)
			callback(result, code)
		end,
	})
end, 2)

---If `fname` has a window open, do nothing.
---Otherwise, split a new window (and possibly buffer) open for that file, respecting `config.split_vertically`.
---
---@param fname string
---@return integer bufnr the identifier of the buffer for `fname`
local function split_unless_open(fname)
	local bufnum = vim.fn.bufnr(vim.fn.expand(fname) --[[@as any]]) --[[@as integer]]
	local winnum = vim.fn.bufwinnr(bufnum)

	if winnum == -1 then
		if M.config.split_vertically then
			vim.cmd.vsplit(fname)
		else
			vim.cmd.split(fname)
		end
	end

	return vim.fn.bufnr(vim.fn.expand(fname) --[[@as any]]) --[[@as integer]]
end

---Get the current time, formatted.
---
---TODO: make this configurable?
local function time()
	return vim.fn.strftime("%a %b %e %H:%M:%S")
end

---Get the default directory, formatted.
---
---TODO: make this configurable?
local function default_dir()
	local cwd = vim.fn.getcwd() --[[@as string]]
	return cwd:gsub("^" .. vim.env.HOME, "~")
end

---Run `command` and place the results in the "Compilation" buffer.
---
---@type fun(command: string)
local runcommand = a.void(function(command)
	local buffer = {
		'-*- mode: compilation; default-directory: "' .. default_dir() .. '" -*-',
		"Compilation started at " .. time(),
		"",
		command,
	}

	local split_cmd = vim.fn.split(command) --[[@as string[] ]]
	local result, code = runjob(split_cmd)
	if #result == 0 then
		table.insert(buffer, "")
	else
		vim.list_extend(buffer, result)
	end

	local simple_message
	local finish_message
	if code == 0 then
		simple_message = "Compilation finished"
		finish_message = "Compilation \x1b[32mfinished\x1b[0m"
	else
		simple_message = "Compilation exited abnormally with code " .. tostring(code)
		finish_message = "Compilation \x1b[31mexited abnormally\x1b[0m with code \x1b[31m"
			.. tostring(code)
			.. "\x1b[0m"
	end

	local compliation_message = M.config.no_baleia_support and simple_message or finish_message
	vim.list_extend(buffer, {
		compliation_message .. " at " .. time(),
		"",
	})

	local bufnr = split_unless_open("Compilation")

	--TODO: set `q` keymap
	--TODO: set ExitPre autocmd

	buf_set_opt(bufnr, "filetype", "compile")

	buf_set_opt(bufnr, "modifiable", true)
	if M.config.no_baleia_support then
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, buffer)
	else
		require("baleia").setup({}).buf_set_lines(bufnr, 0, -1, false, buffer)
	end
	buf_set_opt(bufnr, "modifiable", false)

	vim.notify(simple_message)
end)

---Prompt for (or get by parameter) a command and run it.
---
---@param param CommandParam
M.compile = a.void(function(param)
	param = param or {}

	local command = param.args ~= "" and param.args
		or input({
			prompt = "Compile command: ",
			default = M.prev_command or M.config.default_command or "make -k ",
			completion = "shellcmd",
		})

	if command == nil then
		return
	end

	M.prev_command = command

	runcommand(command)
end)

---Rerun the last command.
M.recompile = a.void(function()
	if M.prev_command then
		runcommand(M.prev_command)
	else
		vim.notify("Cannot recompile without previous command; compile first", vim.log.levels.ERROR)
	end
end)

---Configure `compile-mode.nvim`.
---
---@param config Config
function M.setup(config)
	M.config = config
end

return M
