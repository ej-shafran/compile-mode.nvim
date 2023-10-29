---@alias SplitModifier "aboveleft"|"belowright"|"topleft"|"botright"|""
---@alias SMods { vertical: boolean?, silent: boolean?, split: SplitModifier? }
---@alias CommandParam { args: string?, smods: SMods? }
---@alias Config { no_baleia_support: boolean?, default_command: string?, time_format: string?, baleia_opts: table?, buffer_name: string? }
---@alias IntByInt { [1]: integer, [2]: integer }

local a = require("plenary.async")
---@diagnostic disable-next-line: undefined-field
local buf_set_opt = vim.api.nvim_buf_set_option

local M = {}

---@type string|nil
vim.g.compile_command = nil

---@type string|nil
M.prev_dir = nil
---@type Config
M.config = {}

---TODO: document
---(REGEXP FILE [LINE COLUMN TYPE HYPERLINK HIGHLIGHT...])
---@type table<string, { [1]: string, [2]: integer, [3]: integer|IntByInt|nil, [4]: integer|IntByInt|nil, [5]: nil|0|1|2 }>
local error_regexp_table = {
	-- TODO: use the actual alist from Emacs
	gnu = {
		"^\\%([[:alpha:]][-[:alnum:].]\\+: \\?\\|[ 	]\\%(in \\| from\\)\\)\\?\\(\\%([0-9]*[^0-9\\n]\\)\\%([^\\n :]\\| [^-/\\n]\\|:[^ \\n]\\)\\{-}\\)\\%(: \\?\\)\\([0-9]\\+\\)\\%(-\\([0-9]\\+\\)\\%(\\.\\([0-9]\\+\\)\\)\\?\\|[.:]\\([0-9]\\+\\)\\%(-\\%(\\([0-9]\\+\\)\\.\\)\\([0-9]\\+\\)\\)\\?\\)\\?:\\%( *\\(\\%(FutureWarning\\|RuntimeWarning\\|W\\%(arning\\)\\|warning\\)\\)\\| *\\([Ii]nfo\\%(\\>\\|formationa\\?l\\?\\)\\|I:\\|\\[ skipping .\\+ ]\\|instantiated from\\|required from\\|[Nn]ote\\)\\| *\\%([Ee]rror\\)\\|\\%([0-9]\\?\\)\\%([^0-9\\n]\\|$\\)\\|[0-9][0-9][0-9]\\)",
		1,
		{ 2, 4 },
		{ 3, 5 },
		-- TODO: implement this
		nil,
	},
}

---Parses error syntax from a given line.
---@param line string the line to parse
---@return boolean ok whether there is an error here
---@return nil|string filename the filename for the error
---@return nil|integer r the row of the error
---@return nil|integer c the column of the error
local function parse_error(line)
	local matcher = error_regexp_table["gnu"]
	local regex = matcher[1]
	local result = vim.fn.matchlist(line, regex)
	if not result or #result == 0 or result[1] == "" then
		return false, nil, nil, nil
	end

	local file_index = matcher[2] + 1
	local filename = result[file_index]

	local r
	local r_indices = matcher[3]
	if type(r_indices) == "number" then
		if result[r_indices + 1] and result[r_indices + 1] ~= "" then
			r = result[r_indices + 1]
		else
			return true, filename, 1, 1
		end
	elseif type(r_indices) == "table" then
		local first = r_indices[1] + 1
		local second = r_indices[2] + 1

		if result[first] and result[first] ~= "" then
			r = tonumber(result[first])
		elseif result[second] and result[second] ~= "" then
			r = tonumber(result[second])
		else
			return true, filename, 1, 1
		end
	else
		return true, filename, 1, 1
	end

	local c
	local c_indices = matcher[4]
	if type(c_indices) == "number" then
		if result[c_indices + 1] and result[c_indices + 1] ~= "" then
			c = result[c_indices + 1]
		else
			return true, filename, r, 1
		end
	elseif type(c_indices) == "table" then
		local first = c_indices[1] + 1
		local second = c_indices[2] + 1

		if result[first] and result[first] ~= "" then
			c = tonumber(result[first])
		elseif result[second] and result[second] ~= "" then
			c = tonumber(result[second])
		else
			return true, filename, r, 1
		end
	else
		return true, filename, r, 1
	end

	return true, filename, r, c
end

---@param line string
local function color_statement_prefix(line)
	local ok, filename, r, c = parse_error(line)

	-- TODO: allow customizing these
	local normal = "\x1b[0m"
	local red_bold_underline = "\x1b[31;1;4m"
	-- local green_underline = "\x1b[32;4m"
	-- local normal_underline = "\x1b[0;4m"
	local blue = "\x1b[34m"

	if not ok or not filename or not r or not c then
		-- TODO: place this somewhere else
		-- Also, maybe do this more properly
		return vim.fn.substitute(line, "^\\([^: \\t]\\+\\):", blue .. "\\1" .. normal .. ":", "") --[[@as string]]
	end

	-- TODO: check the type of the command, and use the appropriate matcher
	-- local matcher = error_regexp_table["gnu"]
	-- local regex = matcher[1]

	local start, end_ = string.find(line, filename)
	if start ~= nil and end_ ~= nil then
		line = line:sub(1, start - 1) .. red_bold_underline .. filename .. normal .. line:sub(end_ + 1, -1)
	end

	return line
end

---@param bufnr integer
---@param start integer
---@param end_ integer
---@param flag boolean
---@param lines string[]
local function set_lines(bufnr, start, end_, flag, lines)
	vim.api.nvim_buf_set_lines(bufnr, start, end_, flag, lines)
end

---@type fun(opts: table): string
local input = a.wrap(vim.ui.input, 2)

---@type fun()
local wait = a.wrap(vim.schedule, 1)

---@type fun(cmd: string, bufnr: integer): integer, integer
local runjob = a.wrap(function(cmd, bufnr, callback)
	local count = 0

	local function on_either(_, data)
		if data and (#data > 1 or data[1] ~= "") then
			count = count + #data
			if not M.config.no_baleia_support then
				data = vim.tbl_map(color_statement_prefix, data)
			end

			set_lines(bufnr, -2, -1, false, data)
		end
	end

	vim.fn.jobstart(cmd, {
		cwd = M.prev_dir,
		on_stdout = on_either,
		on_stderr = on_either,
		on_exit = function(_, code)
			callback(count, code)
		end,
	})
end, 3)

---If `fname` has a window open, do nothing.
---Otherwise, split a new window (and possibly buffer) open for that file, respecting `config.split_vertically`.
---
---@param fname string
---@param smods SMods
---@return integer bufnr the identifier of the buffer for `fname`
local function split_unless_open(fname, smods)
	local bufnum = vim.fn.bufnr(vim.fn.expand(fname) --[[@as any]]) --[[@as integer]]
	local winnum = vim.fn.bufwinnr(bufnum)

	if winnum == -1 then
		local cmd = fname
		if smods.vertical then
			cmd = "split " .. cmd
		else
			cmd = "vsplit " .. cmd
		end

		if smods.split and smods.split ~= "" then
			cmd = smods.split .. " " .. cmd
		end

		vim.cmd(cmd)
	end

	return vim.fn.bufnr(vim.fn.expand(fname) --[[@as any]]) --[[@as integer]]
end

---Get the current time, formatted.
local function time()
	local format = "%a %b %e %H:%M:%S"
	if M.config.time_format then
		format = M.config.time_format
	end

	return vim.fn.strftime(format)
end

---Get the default directory, formatted.
local function default_dir()
	local cwd = vim.fn.getcwd() --[[@as string]]
	return cwd:gsub("^" .. vim.env.HOME, "~")
end

---Go to the error on the current line
---@type fun()
local error_on_line = a.void(function()
	local line = vim.api.nvim_get_current_line()
	local ok, filename, r, c = parse_error(line)

	if not ok then
		vim.notify("No error here")
		return
	end

	local file_exists = vim.fn.filereadable(filename) ~= 0

	if file_exists then
		vim.cmd.e(filename)
		vim.api.nvim_win_set_cursor(0, { r, c })
	else
		local dir = input({
			prompt = "Find this error in: ",
			completion = "file",
		})
		if not dir then
			return
		end
		dir = dir:gsub("/$", "")

		wait()

		if not vim.fn.isdirectory(dir) then
			vim.notify(dir .. " is not a directory", vim.log.levels.ERROR)
			return
		end

		local nested_filename = dir .. "/" .. filename
		if vim.fn.filereadable(nested_filename) == 0 then
			vim.notify(filename .. " does not exist in " .. dir, vim.log.levels.ERROR)
			return
		end

		vim.cmd.e(nested_filename)
		c = c - 1
		if c < 0 then
			c = 0
		end
		vim.api.nvim_win_set_cursor(0, { r, c })
	end
end)

---Run `command` and place the results in the "Compilation" buffer.
---
---@type fun(command: string, smods: SMods)
local runcommand = a.void(function(command, smods)
	local bufnr = split_unless_open(M.config.buffer_name or "Compilation", smods)
	buf_set_opt(bufnr, "modifiable", true)
	buf_set_opt(bufnr, "filetype", "compile")
	vim.keymap.set("n", "q", "<CMD>q<CR>", { silent = true, buffer = bufnr })
	vim.keymap.set("n", "<CR>", error_on_line, { silent = true, buffer = bufnr })

	vim.api.nvim_create_autocmd("ExitPre", {
		group = vim.api.nvim_create_augroup("compile-mode", { clear = true }),
		callback = function()
			vim.api.nvim_buf_delete(bufnr, { force = true })
		end,
	})

	if not M.config.no_baleia_support then
		require("baleia").setup(M.config.baleia_opts or {}).automatically(bufnr)
	end

	-- reset compilation buffer
	set_lines(bufnr, 0, -1, false, {})

	set_lines(bufnr, 0, 0, false, {
		'-*- mode: compilation; default-directory: "' .. default_dir() .. '" -*-',
		"Compilation started at " .. time(),
		"",
		color_statement_prefix(command),
	})

	local count, code = runjob(command, bufnr)
	if count == 0 then
		set_lines(bufnr, -1, -1, false, { "" })
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
	set_lines(bufnr, -1, -1, false, {
		compliation_message .. " at " .. time(),
		"",
	})

	if not smods.silent then
		vim.notify(simple_message)
	end

	vim.schedule(function()
		buf_set_opt(bufnr, "modifiable", false)
	end)
end)

---Prompt for (or get by parameter) a command and run it.
---
---@param param CommandParam
M.compile = a.void(function(param)
	param = param or {}

	local command = param.args ~= "" and param.args
		or input({
			prompt = "Compile command: ",
			default = vim.g.compile_command or M.config.default_command or "make -k ",
			completion = "shellcmd",
		})

	if command == nil then
		return
	end

	vim.g.compile_command = command
	M.prev_dir = vim.fn.getcwd()

	runcommand(command, param.smods or {})
end)

---Rerun the last command.
---@param param CommandParam
M.recompile = a.void(function(param)
	if vim.g.compile_command then
		runcommand(vim.g.compile_command, param.smods or {})
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
