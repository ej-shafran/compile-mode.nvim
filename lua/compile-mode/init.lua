---@alias SplitModifier "aboveleft"|"belowright"|"topleft"|"botright"|""
---@alias SMods { vertical: boolean?, silent: boolean?, split: SplitModifier?, hide: boolean? }
---@alias CommandParam { args: string?, smods: SMods?, bang: boolean?, count: integer }
---@alias Config { default_command: string?, time_format: string?, buffer_name: string?, error_regexp_table: ErrorRegexpTable?, debug: boolean?, error_ignore_file_list: string[]?, compilation_hidden_output: (string|string[])?, recompile_no_fail: boolean?, same_window_errors: boolean?, auto_jump_to_first_error: boolean?, ask_about_save: boolean? }

local a = require("plenary.async")
local errors = require("compile-mode.errors")
local utils = require("compile-mode.utils")

local M = {}

--- FILE-GLOBAL VARIABLES

---Line in the compilation buffer that the current error is on;
---acts as an index of `errors.error_list`
local error_cursor = 0

---@type string|nil
local prev_dir = nil

--- UTILITY FUNCTIONS

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
		local command_output_highlights = {}
		for i, line in ipairs(data) do
			local error = errors.parse(line)
			local linenum = linecount + i - 1

			if M.config.compilation_hidden_output then
				local hide
				if type(M.config.compilation_hidden_output) == "string" then
					hide = {
						M.config.compilation_hidden_output,--[[@as string]]
					}
				else
					hide = M.config.compilation_hidden_output --[[@as string[] ]]
				end

				for _, re in ipairs(hide) do
					line = vim.fn.substitute(line, re --[[@as string]], "", "") --[[@as string]]
					data[i] = line
				end
			end

			if error then
				errors.error_list[linenum] = error

				if M.config.auto_jump_to_first_error and #vim.tbl_keys(errors.error_list) == 1 then
					utils.jump_to_error(error, M.config.same_window_errors)
					error_cursor = linenum
				end
			else
				local highlights = utils.match_command_ouput(line, linenum)
				for _, highlight in ipairs(highlights) do
					table.insert(command_output_highlights, highlight)
				end
			end
		end

		set_lines(bufnr, -2, -1, data)
		utils.wait()
		utils.highlight_command_outputs(bufnr, command_output_highlights)
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

---Common exit codes to check against.
---See `:h on_exit` to understand why 128 + signal number
local exit_code = {
	SUCCESS = 0,
	SIGSEGV = 139, -- 128 + signal number 11
	SIGTERM = 143, -- 128 + signal number 15
}

---Run `command` and place the results in the "Compilation" buffer.
---
---@type fun(command: string, smods: SMods, count: integer, sync: boolean | nil)
local runcommand = a.void(function(command, smods, count, sync)
	if M.config.ask_about_save then
		local buffers = vim.api.nvim_list_bufs()
		local buffers_with_changes = vim.tbl_filter(function(bufnr)
			return vim.api.nvim_get_option_value("modified", { buf = bufnr })
		end, buffers)

		for _, bufnr in ipairs(buffers_with_changes) do
			local bufname = vim.api.nvim_buf_get_name(bufnr)
			local result = vim.fn.confirm("Save changes to " .. bufname .. "?", "&Yes\n&No\nSkip &All\n&Quit")

			if result == 1 then
				vim.cmd(tostring(bufnr) .. "bufdo w")
			end

			if result == 3 then
				break
			end

			if result == 4 then
				vim.notify("Quit")
				return
			end
		end
	end

	error_cursor = 0
	errors.error_list = {}

	debug("== runcommand() ==")
	if vim.g.compile_job_id then
		M.interrupt()

		utils.delay(1000)
	end

	debug("== opening compilation buffer ==")

	local bufnr = utils.split_unless_open(M.config.buffer_name, smods, count)
	debug("bufnr = " .. bufnr)

	vim.fn.matchadd("CompileModeInfo", "^Compilation \\zsfinished\\ze.*")
	vim.fn.matchadd(
		"CompileModeError",
		"^Compilation \\zs\\(exited abnormally\\|interrupted\\|killed\\|terminated\\|segmentation fault\\)\\ze"
	)
	vim.fn.matchadd("CompileModeError", "^Compilation .* with code \\zs[0-9]\\+\\ze")
	vim.fn.matchadd("CompileModeOutputFile", " --\\?o\\(utfile\\|utput\\)\\?[= ]\\zs\\(\\S\\+\\)\\ze")

	utils.buf_set_opt(bufnr, "buftype", "nofile")
	utils.buf_set_opt(bufnr, "modifiable", true)
	utils.buf_set_opt(bufnr, "filetype", "compilation")

	vim.api.nvim_buf_create_user_command(bufnr, "CompileGotoError", M.goto_error, {})
	vim.api.nvim_buf_create_user_command(bufnr, "CompileInterrupt", M.interrupt, {})
	vim.api.nvim_buf_create_user_command(bufnr, "CompileNextError", M.move_to_next_error, {})
	vim.api.nvim_buf_create_user_command(bufnr, "CompileNextFile", M.move_to_next_file, {})
	vim.api.nvim_buf_create_user_command(bufnr, "CompilePrevError", M.move_to_prev_error, {})
	vim.api.nvim_buf_create_user_command(bufnr, "CompilePrevFile", M.move_to_prev_file, {})

	vim.keymap.set("n", "q", "<CMD>q<CR>", { silent = true, buffer = bufnr })
	vim.keymap.set("n", "<CR>", "<CMD>CompileGotoError<CR>", { silent = true, buffer = bufnr })
	vim.keymap.set("n", "<C-c>", "<CMD>CompileInterrupt<CR>", { silent = true, buffer = bufnr })

	-- reset compilation buffer
	set_lines(bufnr, 0, -1, {})
	utils.wait()

	local error = errors.parse(command)
	if error then
		errors.error_list[4] = error
	end

	set_lines(bufnr, 0, 0, {
		"vim: filetype=compilation:path+=" .. default_dir(),
		"Compilation started at " .. time(),
		"",
		command,
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

	local compilation_message
	if code == exit_code.SUCCESS then
		compilation_message = "Compilation finished"
	elseif code == exit_code.SIGSEGV then
		compilation_message = "Compilation segmentation fault (core dumped)"
	elseif code == exit_code.SIGTERM then
		compilation_message = "Compilation terminated"
	else
		compilation_message = "Compilation exited abnormally with code " .. tostring(code)
	end

	set_lines(bufnr, -1, -1, {
		compilation_message .. " at " .. time(),
		"",
	})

	if not smods.silent then
		vim.notify(compilation_message)
	end

	utils.wait()

	utils.buf_set_opt(bufnr, "modifiable", false)
	utils.buf_set_opt(bufnr, "modified", false)
end)

---Create a command that takes some action on the next/previous error from the current error cursor.
---
---@param action "jump"|"move" the action to do with the matching error:
--- * "jump" means go to the locus of the error
--- * "move" means scroll to the line in the compilation buffer
---@param direction "next"|"prev" what direction from the error cursor to find matches from:
--- * "next" means work forward from the current error
--- * "prev" means work backwards from the current error
---This also determines the printed message if there is no match in the specified direction.
---@param different_file boolean whether to only match errors that occur in different files from the current error
---@return fun() command an async callback that performs the created action
local function act_from_current_error(action, direction, different_file)
	return a.void(function()
		local current_error = errors.error_list[error_cursor]

		local error_line = nil
		for line, error in pairs(errors.error_list) do
			local fits_file_constraint = true
			if different_file then
				fits_file_constraint = not current_error or error.filename.value ~= current_error.filename.value
			end

			local fits_line_constraint = true
			if direction == "prev" then
				fits_line_constraint = line < error_cursor and (not error_line or error_line < line)
			else
				fits_line_constraint = line > error_cursor and (not error_line or error_line > line)
			end

			if fits_file_constraint and fits_line_constraint then
				error_line = line
			end
		end

		if not error_line then
			local message = direction == "next" and "past last" or "back before first"
			vim.notify("Moved " .. message .. " error")
			return
		end

		error_cursor = error_line
		if action == "jump" then
			utils.jump_to_error(errors.error_list[error_line], M.config.same_window_errors)
		else
			vim.api.nvim_win_set_cursor(0, { error_line, 0 })
		end
	end)
end

--- PUBLIC (NON-COMMAND) API

---@type Config
M.config = {
	buffer_name = "*compilation*",
	default_command = "make -k",
	time_format = "%a %b %e %H:%M:%S",
}

M.level = errors.level

---Configure `compile-mode.nvim`. Also sets up the highlight groups for errors.
---
---@param opts Config
function M.setup(opts)
	debug("== setup() ==")
	M.config = vim.tbl_deep_extend("force", M.config, opts)

	errors.error_regexp_table = vim.tbl_extend("force", errors.error_regexp_table, M.config.error_regexp_table or {})
	errors.ignore_file_list = vim.list_extend(errors.ignore_file_list, M.config.error_ignore_file_list or {})

	vim.cmd("highlight default CompileModeMessage guifg=NONE gui=underline")
	vim.cmd("highlight link CompileModeCommandOutput Function")
	vim.cmd("highlight link CompileModeOutputFile Keyword")
	vim.cmd("highlight default CompileModeMessageRow guifg=Magenta")
	vim.cmd("highlight default CompileModeMessageCol guifg=Cyan")
	vim.cmd("highlight default CompileModeError cterm=bold gui=bold guifg=Red")
	vim.cmd("highlight default CompileModeWarning cterm=bold gui=bold guifg=DarkYellow")
	vim.cmd("highlight default CompileModeInfo cterm=bold gui=bold guifg=Green")

	debug("config = " .. vim.inspect(M.config))
end

--- GENERAL COMMANDS

---Prompt for (or get by parameter) a command and run it.
---
---@type fun(param: CommandParam)
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
---
---@type fun(param: CommandParam)
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

---Jump to the current error in the error list
---
---@type fun()
M.current_error = a.void(function()
	debug("== current_error() ==")

	debug("line = " .. error_cursor)

	local error = errors.error_list[error_cursor]
	if error == nil then
		vim.notify("No error currently loaded", vim.log.levels.ERROR)
		return
	end

	utils.jump_to_error(error, M.config.same_window_errors)
end)

---Jump to the next error in the error list.
---
---@type fun()
M.next_error = act_from_current_error("jump", "next", false)

---Jump to the previous error in the error list.
---
---@type fun()
M.prev_error = act_from_current_error("jump", "prev", false)

---Load all compilation errors into the quickfix list, replacing the existing list.
---
---@type fun()
M.send_to_qflist = a.void(function()
	debug("== send_to_qflist() ==")

	vim.api.nvim_exec_autocmds("QuickFixCmdPre", {})
	vim.fn.setqflist(errors.toqflist(errors.error_list), "r")
	vim.api.nvim_exec_autocmds("QuickFixCmdPost", {})
end)

---Load all compilation errors into the quickfix list, appending onto the existing list.
---
---@type fun()
M.add_to_qflist = a.void(function()
	debug("== add_to_qflist() ==")

	vim.api.nvim_exec_autocmds("QuickFixCmdPre", {})
	vim.fn.setqflist(errors.toqflist(errors.error_list), "a")
	vim.api.nvim_exec_autocmds("QuickFixCmdPost", {})
end)

--- COMPILATION BUFFER COMMANDS

---Go to the error on the current line
---
---@type fun()
M.goto_error = a.void(function()
	debug("== goto_error() ==")

	local linenum = unpack(vim.api.nvim_win_get_cursor(0))
	local error = errors.error_list[linenum]
	debug("error = " .. vim.inspect(error))

	if not error then
		vim.notify("No error here")
		return
	end

	error_cursor = linenum
	utils.jump_to_error(error, M.config.same_window_errors)
end)

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

	local bufnr = vim.fn.bufnr(M.config.buffer_name)
	debug("bufnr = " .. bufnr)

	local interrupt_message = "Compilation interrupted"

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

---Move to the location of the next error within the compilation buffer.
---Does not jump to the error's actual locus.
---
---@type fun()
M.move_to_next_error = act_from_current_error("move", "next", false)

---Move to the location of the next error within the compilation buffer that has a different file to the current one.
---Does not jump to the error's actual locus.
---
---@type fun()
M.move_to_next_file = act_from_current_error("move", "next", true)

---Move to the location of the previous error within the compilation buffer.
---Does not jump to the error's actual locus.
---
---@type fun()
M.move_to_prev_error = act_from_current_error("move", "prev", false)

---Move to the location of the previous error within the compilation buffer that has a different file to the current one.
---Does not jump to the error's actual locus.
---
---@type fun()
M.move_to_prev_file = act_from_current_error("move", "prev", true)

return M
