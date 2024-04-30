---@alias SplitModifier "aboveleft"|"belowright"|"topleft"|"botright"|""
---@alias SMods { vertical: boolean?, silent: boolean?, split: SplitModifier?, hide: boolean? }
---@alias CommandParam { args: string?, smods: SMods?, bang: boolean?, count: integer }
---@alias Config { no_baleia_support: boolean?, default_command: string?, time_format: string?, baleia_opts: table?, buffer_name: string?, error_highlights: false|table<string, HighlightStyle|false>?, error_regexp_table: ErrorRegexpTable?, debug: boolean?, error_ignore_file_list: string[]?, compilation_hidden_output: (string|string[])?, recompile_no_fail: boolean?, same_window_errors: boolean? }

local a = require("plenary.async")
local errors = require("compile-mode.errors")
local utils = require("compile-mode.utils")
local colors = require("compile-mode.colors")

local M = {}

local current_error = 0
---@type string|nil
local prev_dir = nil
---@type Config
M.config = {
	buffer_name = "compilation",
	default_command = "make -k",
	error_highlights = colors.default_highlights,
	time_format = "%a %b %e %H:%M:%S",
}

M.level = errors.level

local debug = a.void(function(...)
	if M.config.debug == true then
		utils.wait()
		print(...)
	end
end)

---@param bufnr integer
---@param start integer
---@param end_ integer
---@param data string[]
local function set_lines(bufnr, start, end_, data)
	vim.api.nvim_buf_set_lines(bufnr, start, end_, false, data)
	vim.api.nvim_buf_call(bufnr, function()
		vim.cmd("normal G")
	end)
end

---Configure `compile-mode.nvim`. Also sets up the highlight groups for errors.
---
---@param opts Config
function M.setup(opts)
	debug("== setup() ==")
	M.config = vim.tbl_deep_extend("force", M.config, opts)

	errors.error_regexp_table = vim.tbl_extend("force", errors.error_regexp_table, M.config.error_regexp_table or {})
	errors.ignore_file_list = vim.list_extend(errors.ignore_file_list, M.config.error_ignore_file_list or {})

	if M.config.error_highlights then
		colors.setup_highlights(M.config.error_highlights)
	end

	debug("config = " .. vim.inspect(M.config))
end

---@type fun(cmd: string, bufnr: integer, sync: boolean | nil): integer, integer, integer
local runjob = a.wrap(function(cmd, bufnr, sync, callback)
	debug("== runjob() ==")

	local count = 0

	local on_either = a.void(function(_, data)
		if not data or #data < 1 or (#data == 1 and data[1] == "") then
			return
		end

		count = count + #data

		local linecount = vim.api.nvim_buf_line_count(bufnr)
		for i, line in ipairs(data) do
			local error = errors.parse(line)

			if M.config.compilation_hidden_output then
				local hide
				if type(M.config.compilation_hidden_output) == "string" then
					hide = { M.config.compilation_hidden_output }
				else
					hide = M.config.compilation_hidden_output --[[@as string[] ]]
				end

				for _, re in ipairs(hide) do
					line = vim.fn.substitute(line, re, "", "") --[[@as string]]
					data[i] = line
				end
			end

			if error then
				errors.error_list[linecount + i - 1] = error
			elseif not M.config.no_baleia_support then
				line = vim.fn.substitute(line, "^\\([^: \\t]\\+\\):", "\x1b[34m\\1\x1b[0m:", "")
				data[i] = line
			end
		end

		set_lines(bufnr, -2, -1, data)
		utils.wait()
		errors.highlight(bufnr)
	end)

	debug("== starting job ==")
	local job_id = vim.fn.jobstart(cmd, {
		cwd = prev_dir,
		on_stdout = on_either,
		on_stderr = on_either,
		on_exit = function(id, code)
			callback(count, code, id)
		end,
	})
	debug("job_id = " .. job_id)

	if job_id <= 0 then
		vim.notify("Failed to start job with command " .. cmd, vim.log.levels.ERROR)
		return
	end

	vim.g.compile_job_id = job_id

	if sync then
		debug("== sync mode - waiting for job to finish ==")
		vim.fn.jobwait({ job_id })
	end

	vim.api.nvim_create_autocmd({ "BufDelete" }, {
		buffer = bufnr,
		callback = function()
			vim.fn.jobstop(job_id)
		end,
	})
end, 4)

---Get the current time, formatted.
local function time()
	return vim.fn.strftime(M.config.time_format)
end

---Get the default directory, formatted.
local function default_dir()
	local cwd = vim.fn.getcwd() --[[@as string]]
	return cwd:gsub("^" .. vim.env.HOME, "~")
end

---Go to the error on the current line
function M.goto_error()
	debug("== goto_error() ==")

	local linenum = unpack(vim.api.nvim_win_get_cursor(0))
	local error = errors.error_list[linenum]
	debug("error = " .. vim.inspect(error))

	if not error then
		vim.notify("No error here")
		return
	end

	utils.jump_to_error(error, M.config.same_window_errors)
end

---Interrupt the currently running compilation command.
---
---@type fun()
M.interrupt = a.void(function()
	debug("== interrupt() ==")

	if not vim.g.compile_job_id then
		debug("== nothing to interrupt ==")
		return
	end

	debug("== interrupting compilation ==")
	debug("vim.g.compile_job_id = ", vim.g.compile_job_id)

	local bufnr = utils.bufnr(M.config.buffer_name)
	debug("bufnr = " .. bufnr)

	local interrupt_message
	if not M.config.no_baleia_support then
		interrupt_message = "Compilation \x1b[31minterrupted\x1b[0m"
	else
		interrupt_message = "Compilation interrupted"
	end

	utils.buf_set_opt(bufnr, "modifiable", true)
	set_lines(bufnr, -1, -1, {
		"",
		interrupt_message .. " at " .. time(),
	})
	utils.wait()
	utils.buf_set_opt(bufnr, "modifiable", false)

	vim.fn.jobstop(vim.g.compile_job_id)
	vim.g.compile_job_id = nil
end)

---Run `command` and place the results in the "Compilation" buffer.
---
---@type fun(command: string, smods: SMods, count: integer, sync: boolean | nil)
local runcommand = a.void(function(command, smods, count, sync)
	current_error = 0
	errors.error_list = {}

	debug("== runcommand() ==")
	if vim.g.compile_job_id then
		M.interrupt()

		utils.delay(1000)
	end

	debug("== opening compilation buffer ==")

	local bufnr = utils.split_unless_open(M.config.buffer_name, smods, count)
	debug("bufnr = " .. bufnr)

	utils.buf_set_opt(bufnr, "buftype", "nofile")
	utils.buf_set_opt(bufnr, "modifiable", true)
	utils.buf_set_opt(bufnr, "filetype", "compilation")

	vim.keymap.set("n", "q", "<CMD>q<CR>", { silent = true, buffer = bufnr })
	vim.keymap.set("n", "<CR>", "<CMD>CompileGotoError<CR>", { silent = true, buffer = bufnr })
	vim.keymap.set("n", "<C-c>", "<CMD>CompileInterrupt<CR>", { silent = true, buffer = bufnr })

	if not M.config.no_baleia_support then
		local baleia = require("baleia").setup(M.config.baleia_opts or {})
		baleia.automatically(bufnr)
		vim.api.nvim_create_user_command("BaleiaLogs", function()
			baleia.logger.show()
		end, {})
	end

	-- reset compilation buffer
	set_lines(bufnr, 0, -1, {})
	utils.wait()

	local rendered_command = command

	local error = errors.parse(command)
	if error then
		errors.error_list[4] = error
	elseif not M.config.no_baleia_support then
		rendered_command = vim.fn.substitute(command, "^\\([^: \\t]\\+\\):", "\x1b[34m\\1\x1b[0m:", "")
	end

	set_lines(bufnr, 0, 0, {
		'-*- mode: compilation; default-directory: "' .. default_dir() .. '" -*-',
		"Compilation started at " .. time(),
		"",
		rendered_command,
	})

	utils.wait()
	errors.highlight(bufnr)

	debug("== running command: `" .. string.gsub(command, "\\`", "\\`") .. "` ==")
	local line_count, code, job_id = runjob(command, bufnr, sync)
	if job_id ~= vim.g.compile_job_id then
		return
	end
	vim.g.compile_job_id = nil

	if line_count == 0 then
		set_lines(bufnr, -1, -1, { "" })
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
	set_lines(bufnr, -1, -1, {
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
	debug("== compile() ==")
	param = param or {}

	local command = param.args ~= "" and param.args
		or utils.input({
			prompt = "Compile command: ",
			default = vim.g.compile_command or M.config.default_command,
			completion = "shellcmd",
		})

	if command == nil then
		return
	end

	vim.g.compile_command = command
	prev_dir = vim.fn.getcwd()

	runcommand(command, param.smods or {}, param.count, param.bang)
end)

---Rerun the last command.
---@param param CommandParam
M.recompile = a.void(function(param)
	debug("==recompile()==")
	if vim.g.compile_command then
		runcommand(vim.g.compile_command, param.smods or {}, param.count, param.bang)
	elseif M.config.recompile_no_fail then
		M.compile(param)
	else
		vim.notify("Cannot recompile without previous command; compile first", vim.log.levels.ERROR)
	end
end)

---Jump to the next error in the error list.
M.next_error = a.void(function()
	debug("== next_error() ==")

	local lowest_above = nil
	for line, _ in pairs(errors.error_list) do
		if line > current_error and (not lowest_above or lowest_above > line) then
			lowest_above = line
		end
	end

	if not lowest_above then
		vim.notify("Moved past last error")
		return
	end
	debug("line = " .. lowest_above)

	current_error = lowest_above
	debug("current_error = " .. current_error)
	utils.jump_to_error(errors.error_list[lowest_above], M.config.same_window_errors)
end)

---Jump to the previous error in the error list.
M.prev_error = a.void(function()
	debug("== prev_error() ==")

	local highest_below = nil
	for line, _ in pairs(errors.error_list) do
		if line < current_error and (not highest_below or highest_below < line) then
			highest_below = line
		end
	end

	if not highest_below then
		vim.notify("Moved past first error")
		return
	end
	debug("line = " .. highest_below)

	current_error = highest_below
	debug("current_error = " .. current_error)
	utils.jump_to_error(errors.error_list[highest_below], M.config.same_window_errors)
end)

return M
