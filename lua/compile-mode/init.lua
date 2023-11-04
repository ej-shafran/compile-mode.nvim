---@alias SplitModifier "aboveleft"|"belowright"|"topleft"|"botright"|""
---@alias SMods { vertical: boolean?, silent: boolean?, split: SplitModifier? }
---@alias CommandParam { args: string?, smods: SMods? }
---@alias Config { no_baleia_support: boolean?, default_command: string?, time_format: string?, baleia_opts: table?, buffer_name: string?, error_highlights: false|table<string, HighlightStyle|false>? }

local a = require("plenary.async")
local errors = require("compile-mode.errors")
local utils = require("compile-mode.utils")

local M = {}

local default_colors = {
	[0] = "Black",
	[1] = "DarkRed",
	[2] = "DarkGreen",
	[3] = "DarkYellow",
	[4] = "DarkBlue",
	[5] = "DarkMagenta",
	[6] = "DarkCyan",
	[7] = "LightGrey",
	[8] = "DarkGrey",
	[9] = "LightRed",
	[10] = "LightGreen",
	[11] = "LightYellow",
	[12] = "LightBlue",
	[13] = "LightMagenta",
	[14] = "LightCyan",
	[15] = "White",
}

local theme_colors = {}

for index = 0, 255 do
	local color = vim.g["terminal_color_" .. index]
	theme_colors[index] = color or default_colors[index]
end

---@type string|nil
M.prev_dir = nil
---@type Config
M.config = {
	error_highlights = {
		error = {
			gui = "underline",
		},
		error_row = {
			gui = "underline",
			foreground = theme_colors[2],
		},
		error_col = {
			gui = "underline",
			foreground = theme_colors[8],
		},
		error_filename = {
			gui = "bold,underline",
			foreground = theme_colors[9],
		},
		warning_filename = {
			gui = "underline",
			foreground = theme_colors[3],
		},
		info_filename = {
			gui = "underline",
			foreground = theme_colors[14],
		},
	},
}

---Configure `compile-mode.nvim`.
---
---@param config Config
function M.setup(config)
	M.config = vim.tbl_deep_extend("force", M.config, config)

	if M.config.error_highlights then
		utils.create_hlgroup("CompileModeError", M.config.error_highlights.error or {})
		utils.create_hlgroup("CompileModeErrorRow", M.config.error_highlights.error_row or {})
		utils.create_hlgroup("CompileModeErrorCol", M.config.error_highlights.error_col or {})

		utils.create_hlgroup("CompileModeErrorFilename", M.config.error_highlights.error_filename or {})
		utils.create_hlgroup("CompileModeWarningFilename", M.config.error_highlights.warning_filename or {})
		utils.create_hlgroup("CompileModeInfoFilename", M.config.error_highlights.info_filename or {})
	end
end

---@type fun(cmd: string, bufnr: integer): integer, integer
local runjob = a.wrap(function(cmd, bufnr, callback)
	local count = 0

	local on_either = a.void(function(_, data)
		if not data or (#data < 1 or data[1] == "") then
			return
		end

		count = count + #data

		local linecount = vim.api.nvim_buf_line_count(bufnr)
		for i, line in ipairs(data) do
			local error = errors.parse(line)

			if error then
				errors.error_list[linecount + i - 1] = error
			elseif not M.config.no_baleia_support then
				data[i] = vim.fn.substitute(line, "^\\([^: \\t]\\+\\):", "\x1b[34m\\1\x1b[0m:", "")
			end
		end

		vim.api.nvim_buf_set_lines(bufnr, -2, -1, false, data)
		utils.wait()
		errors.highlight(bufnr)
	end)

	local id = vim.fn.jobstart(cmd, {
		cwd = M.prev_dir,
		on_stdout = on_either,
		on_stderr = on_either,
		on_exit = function(_, code)
			callback(count, code)
		end,
	})

	if id <= 0 then
		vim.notify("Failed to start job with command " .. cmd, vim.log.levels.ERROR)
		return
	end

	vim.api.nvim_create_autocmd({ "BufDelete" }, {
		buffer = bufnr,
		callback = function()
			vim.fn.jobstop(id)
		end,
	})
end, 3)

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
function M.goto_error()
	local linenum = unpack(vim.api.nvim_win_get_cursor(0))
	local error = errors.error_list[linenum]

	if not error then
		vim.notify("No error here")
		return
	end

	utils.jump_to_error(error)
end

---Run `command` and place the results in the "Compilation" buffer.
---
---@type fun(command: string, smods: SMods)
local runcommand = a.void(function(command, smods)
	local bufnr = utils.split_unless_open(M.config.buffer_name or "Compilation", smods)

	utils.buf_set_opt(bufnr, "modifiable", true)
	utils.buf_set_opt(bufnr, "filetype", "compilation")

	vim.keymap.set("n", "q", "<CMD>q<CR>", { silent = true, buffer = bufnr })
	vim.keymap.set("n", "<CR>", "<CMD>CompileGotoError<CR>", { silent = true, buffer = bufnr })

	vim.api.nvim_create_autocmd("ExitPre", {
		group = vim.api.nvim_create_augroup("compile-mode", { clear = true }),
		callback = function()
			if vim.api.nvim_buf_is_valid(bufnr) then
				vim.api.nvim_buf_delete(bufnr, { force = true })
			end
		end,
	})

	if not M.config.no_baleia_support then
		local baleia = require("baleia").setup(M.config.baleia_opts or {})
		baleia.automatically(bufnr)
		vim.api.nvim_create_user_command("BaleiaLogs", function()
			baleia.logger.show()
		end, {})
	end

	-- reset compilation buffer
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})

	local rendered_command = command

	local error = errors.parse(command)
	if error then
		errors.error_list[4] = error
	elseif not M.config.no_baleia_support then
		rendered_command = vim.fn.substitute(command, "^\\([^: \\t]\\+\\):", "\x1b[34m\\1\x1b[0m:", "")
	end

	vim.api.nvim_buf_set_lines(bufnr, 0, 0, false, {
		'-*- mode: compilation; default-directory: "' .. default_dir() .. '" -*-',
		"Compilation started at " .. time(),
		"",
		rendered_command,
	})

	utils.wait()
	errors.highlight(bufnr)

	local count, code = runjob(command, bufnr)
	if count == 0 then
		vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { "" })
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
	vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, {
		compliation_message .. " at " .. time(),
		"",
	})

	if not smods.silent then
		vim.notify(simple_message)
	end

	utils.wait()

	utils.buf_set_opt(bufnr, "modifiable", false)
	utils.buf_set_opt(bufnr, "modified", false)
end)

---Prompt for (or get by parameter) a command and run it.
---
---@param param CommandParam
M.compile = a.void(function(param)
	param = param or {}

	local command = param.args ~= "" and param.args
		or utils.input({
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

return M
