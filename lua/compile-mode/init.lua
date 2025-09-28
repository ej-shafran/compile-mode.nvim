---@alias SplitModifier
---|"aboveleft"
---|"belowright"
---|"topleft"
---|"botright"
---|""

---@class SMods
---
---@field vertical?   boolean
---@field silent?     boolean
---@field hide?       boolean
---@field tab?        integer
---@field split?      SplitModifier
---@field noswapfile? boolean

---@class CommandParam
---
---@field args?  string
---@field smods? SMods
---@field bang?  boolean
---@field count? integer

local a = require("plenary.async")
local errors = require("compile-mode.errors")
local utils = require("compile-mode.utils")
local log = require("compile-mode.log")

local M = {}

--- FILE-GLOBAL VARIABLES

---Line in the compilation buffer that the current error is on;
---acts as an index of `errors.error_list`
local error_cursor = 0

---The previous directory used for compilation.
---@type string|nil
local compilation_directory = nil

---A table which keeps track of the changes in directory for the compilation buffer,
---based on "Entering directory" and "Leaving directory" messages.
---@type table<integer, string>
local dir_changes = {}

---Whether or not to preview the error under the cursor.
local in_next_error_mode = false

--- UTILITY FUNCTIONS

---@param bufnr integer
---@param start integer
---@param end_ integer
---@param data string[]
local function set_lines(bufnr, start, end_, data)
	if vim.fn.bufexists(bufnr) == 0 then
		return
	end

	utils.buf_set_opt(bufnr, "modifiable", true)
	vim.api.nvim_buf_set_lines(bufnr, start, end_, false, data)
	vim.schedule(function()
		utils.buf_set_opt(bufnr, "modifiable", false)
		utils.buf_set_opt(bufnr, "modified", false)
	end)
	vim.api.nvim_buf_call(bufnr, function()
		vim.cmd("normal G")
	end)
end

---Get the directory to look in for a specific line in the compilation buffer,
---while respecting "Entering directory" and "Leaving directory" messages.
---@param linenum integer the line number to check the directory for
---@return string
local function find_directory_for_line(linenum)
	local latest_linenum = nil
	local dir = compilation_directory or vim.fn.getcwd()
	for old_linenum, old_dir in pairs(dir_changes) do
		if old_linenum < linenum and (not latest_linenum or latest_linenum <= old_linenum) then
			latest_linenum = old_linenum
			dir = old_dir
		end
	end
	return dir
end

---Like `:find`, but splits unless `same_window` is configured.
---@param file string the file to find
---@param same_window boolean if `true`, do not split
local function file_find(file, same_window)
	if not same_window and vim.fn.filereadable(file) ~= 0 then
		vim.cmd("split")
	end

	local ok, msg = pcall(vim.cmd.find, file)
	if not ok then
		vim.notify(string.gsub(msg, "^Vim:", ""), vim.log.levels.ERROR)
	end
end

---Returns a function that acts like `gf` or `CTRL-W_f` (depending on the `same_window` parameter),
---while respecting "Entering directory" and "Leaving directory" messages.
---@param same_window boolean whether to split (i.e. act like `gf`) or not (i.e. act like `CTRL-W_f`)
---@return fun()
local function goto_file(same_window)
	return function()
		local cfile = vim.fn.expand("<cfile>")
		local linenum = unpack(vim.api.nvim_win_get_cursor(0))

		local dir = find_directory_for_line(linenum)

		vim.cmd("set path+=" .. dir)
		file_find(cfile, same_window)
		vim.cmd("set path-=" .. dir)
	end
end

---@type fun(cmd: string, bufnr: integer, param: CommandParam): integer, integer, integer
local runjob = a.wrap(
	---@param cmd string
	---@param bufnr integer
	---@param param CommandParam
	---@param callback fun(integer, integer, integer)
	function(cmd, bufnr, param, callback)
		local config = require("compile-mode.config.internal")

		log.debug("calling runjob()")

		local count = 0
		local partial_line = ""
		local is_exited = false

		local on_either = a.void(function(_, data)
			if is_exited or not data or #data < 1 or (#data == 1 and data[1] == "") then
				return
			end

			count = count + #data

			local new_lines = { partial_line .. data[1] }
			for i = 2, #data do
				table.insert(new_lines, data[i])
			end
			partial_line = new_lines[#new_lines]

			for i, line in ipairs(new_lines) do
				for _, re in ipairs(config.hidden_output) do
					line = vim.fn.substitute(line, re, "", "")
					new_lines[i] = line
				end

				if new_lines[i]:sub(-1) == "\r" then
					new_lines[i] = new_lines[i]:sub(1, -2)
				end
			end

			set_lines(bufnr, -2, -1, new_lines)
			utils.wait()
			M._parse_errors(bufnr)
		end)

		log.debug("starting job...")
		local job_id = vim.fn.jobstart(cmd, {
			cwd = compilation_directory,
			on_stdout = on_either,
			on_stderr = on_either,
			on_exit = function(id, code)
				is_exited = true
				callback(count, code, id)
			end,
			env = config.environment,
			clear_env = config.clear_environment,
		})
		log.fmt_debug("job_id = %d", job_id)

		if job_id <= 0 then
			vim.notify("Failed to start job with command " .. cmd, vim.log.levels.ERROR)
			return
		end

		vim.g.compile_job_id = job_id

		if param.bang then
			log.debug("sync mode - waiting for job to finish...")
			vim.fn.jobwait({ job_id })
		end

		vim.api.nvim_create_autocmd({ "BufDelete" }, {
			buffer = bufnr,
			callback = function()
				vim.fn.jobstop(job_id)
			end,
		})
	end,
	4
)

---Get the current time, formatted.
local function time()
	local config = require("compile-mode.config.internal")
	return vim.fn.strftime(config.time_format)
end

---Get the default directory, formatted.
local function default_dir()
	local cwd = compilation_directory or vim.fn.getcwd() --[[@as string]]
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
---@type fun(command: string, param: CommandParam)
local runcommand = a.void(
	---@param command string
	---@param param CommandParam
	function(command, param)
		local config = require("compile-mode.config.internal")

		log.debug("calling runcommand()")

		if config.ask_about_save and utils.ask_to_save(param.smods or {}) then
			return
		end

		error_cursor = 0
		errors.error_list = {}
		dir_changes = {}
		utils.clear_diagnostics()

		if vim.g.compile_job_id then
			if config.ask_to_interrupt then
				local response = vim.fn.confirm("Interrupt running process?", "&Yes\n&No")
				if response ~= 1 then
					return
				end
			end

			M.interrupt()

			utils.delay(1000)
		end

		log.debug("opening compilation buffer...")

		local prev_win = vim.api.nvim_get_current_win()
		local bufnr = utils.split_unless_open(
			{ fname = config.buffer_name },
			vim.tbl_extend("force", param.smods or {}, { noswapfile = true }),
			param.count
		)
		utils.wait()

		if config.focus_compilation_buffer then
			vim.api.nvim_set_current_win(vim.fn.win_findbuf(bufnr)[1])
		else
			vim.api.nvim_set_current_win(prev_win)
		end

		log.fmt_debug("bufnr = %d", bufnr)

		utils.buf_set_opt(bufnr, "buftype", "nofile")
		utils.buf_set_opt(bufnr, "buflisted", not config.hidden_buffer)

		-- reset compilation buffer
		set_lines(bufnr, 0, -1, {})
		utils.wait()

		utils.buf_set_opt(bufnr, "filetype", "compilation")

		if config.bang_expansion then
			command = vim.fn.expandcmd(command)
		end

		local error = errors.parse(command, 4)
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

		log.fmt_debug("running command: %s", command)

		local start_time = vim.loop.hrtime()

		local line_count, code, job_id = runjob(command, bufnr, param)

		local elapsed = (vim.loop.hrtime() - start_time) / 1e9

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

		local fmt_elapsed = string.format(", duration %.2f s", elapsed)

		set_lines(bufnr, -1, -1, {
			compilation_message .. " at " .. time() ..  fmt_elapsed,
			"",
		})

		if not param.smods or not param.smods.silent then
			vim.notify(compilation_message)
		end

		vim.api.nvim_exec_autocmds("User", {
			pattern = "CompilationFinished",
			data = {
				command = command,
				code = code,
				bufnr = bufnr,
			},
		})

		utils.wait()
	end
)

---Create a command that takes some action on the next/previous error from the current error cursor.
---The command is repeated equal to the `count` that it receives, which defaults to `1`.
---
---@param action "jump"|"move" the action to do with the matching error:
--- * "jump" means go to the locus of the error
--- * "move" means scroll to the line in the compilation buffer
---@param direction "next"|"prev" what direction from the error cursor to find matches from:
--- * "next" means work forward from the current error
--- * "prev" means work backwards from the current error
---This also determines the printed message if there is no match in the specified direction.
---@param different_file boolean whether to only match errors that occur in different files from the current error
---@return fun(param: CommandParam?) command an async callback that performs the created action
local function act_from_current_error(action, direction, different_file)
	local name = (action == "jump" and "" or "move_to_") .. direction .. "_" .. (different_file and "file" or "error")
	return a.void(function(param)
		local config = require("compile-mode.config.internal")

		log.debug("calling " .. name .. "()")

		param = param or {}

		local count = param.count or 1
		local current_error = errors.error_list[error_cursor]

		local lines = vim.tbl_keys(errors.error_list)
		table.sort(lines)

		local error_line = nil
		local errors_found = 0
		for i = direction == "prev" and #lines or 1, direction == "prev" and 1 or #lines, direction == "prev" and -1 or 1 do
			local line = lines[i]
			local error = errors.error_list[line]

			local fits_threshold_constraint = error.level >= config.error_threshold

			local fits_file_constraint = true
			if different_file then
				fits_file_constraint = not current_error or error.filename.value ~= current_error.filename.value
			end

			local fits_line_constraint
			if direction == "prev" then
				fits_line_constraint = line < error_cursor and (not error_line or error_line < line)
			else
				fits_line_constraint = line > error_cursor and (not error_line or error_line > line)
			end

			if fits_threshold_constraint and fits_file_constraint and fits_line_constraint then
				errors_found = errors_found + 1
				if errors_found == count then
					error_line = line
					break
				end
			end
		end

		if not error_line then
			if not param.smods or not param.smods.silent then
				local message = direction == "next" and "past last" or "back before first"
				vim.notify("Moved " .. message .. " error")
			end

			return
		end

		error_cursor = error_line
		if action == "jump" then
			local dir = find_directory_for_line(error_line)
			utils.jump_to_error(errors.error_list[error_line], dir, param.smods or {})
		else
			vim.api.nvim_win_set_cursor(0, { error_line, 0 })
		end
	end)
end

--- PUBLIC (NON-COMMAND) API

M.level = errors.level

--- GENERAL COMMANDS

---Prompt for (or get by parameter) a command and run it.
---
---@type fun(param: CommandParam?)
M.compile = a.void(
	---@param param CommandParam?
	function(param)
		local config = require("compile-mode.config.internal")

		log.debug("calling compile()")

		param = param or {}

		local command = param.args
		if not command or command == "" then
			local input_completion_func = "CompileInputComplete"
			if package.loaded["cmp_cmdline_prompt"] or config.input_word_completion then
				input_completion_func = "CompileInputCompleteWord"
			end

			command = utils.input({
				prompt = "Compile command: ",
				default = vim.g.compile_command or config.default_command,
				completion = ("customlist,%s"):format(input_completion_func),
			})
		end

		if command == nil then
			return
		end

		vim.g.compile_command = command
		compilation_directory = vim.g.compilation_directory or vim.fn.getcwd()

		runcommand(command, param)
		vim.g.compilation_directory = nil
	end
)

---Rerun the last command.
---
---@type fun(param: CommandParam?)
M.recompile = a.void(
	---@param param CommandParam?
	function(param)
		local config = require("compile-mode.config.internal")

		log.debug("calling recompile()")

		param = param or {}

		if vim.g.compile_command then
			runcommand(vim.g.compile_command, param)
		elseif config.recompile_no_fail then
			M.compile(param)
		else
			vim.notify("Cannot recompile without previous command; compile first", vim.log.levels.ERROR)
		end
	end
)

---Jump to the Nth error in the error list, based on the count
---
---@type fun(param: CommandParam?)
M.first_error = a.void(
	---@param param CommandParam?
	function(param)
		local config = require("compile-mode.config.internal")

		log.debug("calling first_error()")

		param = param or {}

		local count = param.count or 1
		log.fmt_debug("count = %d", count)

		local lines = vim.iter(pairs(errors.error_list))
			:filter(function(_, error)
				return error.level >= config.error_threshold
			end)
			:map(function(line, _)
				return line
			end)
			:totable()

		if count < 1 then
			vim.notify("Moved back before first error")
			return
		end

		if count > #lines then
			vim.notify("Moved past last error")
			return
		end

		table.sort(lines)

		error_cursor = assert(lines[count])
		local error = assert(errors.error_list[error_cursor])

		local dir = find_directory_for_line(error_cursor)
		utils.jump_to_error(error, dir, param.smods or {})
	end
)

---Jump to the current error in the error list
---
---@type fun(param: CommandParam?)
M.current_error = a.void(
	---@param param CommandParam?
	function(param)
		log.debug("calling current_error()")

		param = param or {}

		log.fmt_debug("line = %d", error_cursor)

		local error = errors.error_list[error_cursor]
		if not error then
			if not param.smods or not param.smods.silent then
				vim.notify("No error currently loaded")
			end

			return
		end

		local dir = find_directory_for_line(error_cursor)
		utils.jump_to_error(error, dir, param.smods or {})
	end
)

---Jump to the next error in the error list.
M.next_error = act_from_current_error("jump", "next", false)

---Jump to the previous error in the error list.
M.prev_error = act_from_current_error("jump", "prev", false)

---Load all compilation errors into the quickfix list, replacing the existing list.
---
---@type fun()
M.send_to_qflist = a.void(function()
	log.debug("calling send_to_qflist()")

	vim.api.nvim_exec_autocmds("QuickFixCmdPre", {})
	vim.fn.setqflist(errors.toqflist(errors.error_list), "r")
	vim.api.nvim_exec_autocmds("QuickFixCmdPost", {})
end)

---Load all compilation errors into the quickfix list, appending onto the existing list.
---
---@type fun()
M.add_to_qflist = a.void(function()
	log.debug("calling add_to_qflist()")

	vim.api.nvim_exec_autocmds("QuickFixCmdPre", {})
	vim.fn.setqflist(errors.toqflist(errors.error_list), "a")
	vim.api.nvim_exec_autocmds("QuickFixCmdPost", {})
end)

---Toggle "Next Error Follow", which causes the error under the cursor to be previewed whenever you move in the compilation buffer.
function M.next_error_follow()
	in_next_error_mode = not in_next_error_mode
	M._follow_cursor()
end

--- COMPILATION BUFFER COMMANDS

---Go to the error on the current line.
---
---@type fun(param: CommandParam?)
M.goto_error = a.void(
	---@param param CommandParam?
	function(param)
		log.debug("calling goto_error()")

		param = param or {}

		local linenum = unpack(vim.api.nvim_win_get_cursor(0))
		local error = errors.error_list[linenum]
		log.fmt_debug("error = %s", error)

		if not error then
			if not param.smods or not param.smods.silent then
				vim.notify("No error here")
			end

			return
		end

		local dir = find_directory_for_line(linenum)

		error_cursor = linenum
		utils.jump_to_error(error, dir, param.smods or {})
	end
)

---Print information about the error on the current line.
---
---@type fun()
M.debug_error = a.void(function()
	log.debug("calling debug_error()")

	local linenum = unpack(vim.api.nvim_win_get_cursor(0))
	local error = errors.error_list[linenum]
	if not error then
		vim.notify("No error here")
		return
	end

	print(("error = %s"):format(vim.inspect(error)))
end)

---Interrupt the currently running compilation command.
---
---@type fun()
M.interrupt = a.void(function()
	log.debug("calling interrupt()")

	if not vim.g.compile_job_id then
		log.debug("nothing to interrupt")
		return
	end

	log.debug("interrupting compilation")
	log.fmt_debug("vim.g.compile_job_id = %d", vim.g.compile_job_id)

	local bufnr = vim.g.compilation_buffer
	log.fmt_debug("bufnr = %d", bufnr)

	local interrupt_message = "Compilation interrupted"

	set_lines(bufnr, -1, -1, {
		"",
		interrupt_message .. " at " .. time(),
	})
	utils.wait()

	local job_id = vim.g.compile_job_id
	vim.fn.jobstop(job_id)
	vim.g.compile_job_id = nil
	vim.api.nvim_exec_autocmds("User", {
		pattern = "CompilationInterrupted",
		data = {
			job_id = job_id,
			bufnr = bufnr,
		},
	})
end)

---Close the compilation buffer.
function M.close_buffer()
	local bufnr = vim.g.compilation_buffer

	local winnrs = vim.fn.win_findbuf(bufnr)

	if #vim.api.nvim_list_wins() > 1 then
		vim.iter(winnrs):each(function(winnr)
			vim.api.nvim_win_close(winnr, true)
		end)
	elseif vim.fn.bufexists("#") ~= 0 then
		vim.cmd.buffer("#")
	else
		vim.cmd.bnext()
	end
end

---Move to the location of the next error within the compilation buffer.
---Does not jump to the error's actual locus.
M.move_to_next_error = act_from_current_error("move", "next", false)

---Move to the location of the next error within the compilation buffer that has a different file to the current one.
---Does not jump to the error's actual locus.
M.move_to_next_file = act_from_current_error("move", "next", true)

---Move to the location of the previous error within the compilation buffer.
---Does not jump to the error's actual locus.
M.move_to_prev_error = act_from_current_error("move", "prev", false)

---Move to the location of the previous error within the compilation buffer that has a different file to the current one.
---Does not jump to the error's actual locus.
M.move_to_prev_file = act_from_current_error("move", "prev", true)

-- OUTWARD-FACING UTILITIES

M._gf = goto_file(false)

M._CTRL_W_f = goto_file(true)

---@param bufnr integer
function M._parse_errors(bufnr)
	local config = require("compile-mode.config.internal")

	errors.error_list = {}
	utils.clear_highlights(bufnr)

	local output_highlights = {}
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	for linenum, line in ipairs(lines) do
		local error = errors.parse(line, linenum)

		if error then
			errors.error_list[linenum] = error

			if config.auto_jump_to_first_error and #vim.tbl_keys(errors.error_list) == 1 then
				local dir = find_directory_for_line(linenum)
				utils.jump_to_error(error, dir, {})
				error_cursor = linenum
			end
		else
			local dirchange = vim.fn.matchlist(line, "\\%(Entering\\|Leavin\\(g\\)\\) directory [`']\\(.\\+\\)'$")
			if #dirchange > 0 then
				local leaving = dirchange[2] ~= ""
				local dir = dirchange[3]

				local latest_dir = find_directory_for_line(linenum)

				if utils.is_absolute(dir) then
					dir_changes[linenum] = vim.fn.fnamemodify(dir, leaving and ":h" or "")
				else
					if leaving then
						dir_changes[linenum] = vim.fn.fnamemodify(latest_dir, ":h")
					else
						dir_changes[linenum] = vim.fn.resolve(latest_dir .. "/" .. dir)
					end
				end
			end

			if not (linenum == 1 and vim.startswith(line, "vim:")) then
				local highlights = utils.match_command_ouput(line, linenum)
				for _, value in ipairs(highlights) do
					table.insert(output_highlights, value)
				end
			end
		end
	end

	errors.highlight(bufnr)
	utils.highlight_command_outputs(bufnr, output_highlights)
end

function M._follow_cursor()
	local compilation_buffer = vim.g.compilation_buffer

	if not in_next_error_mode then
		return
	end

	if vim.api.nvim_get_current_buf() ~= compilation_buffer then
		return
	end

	local cursor_row = unpack(vim.api.nvim_win_get_cursor(0))
	local error = errors.error_list[cursor_row]
	if not error then
		return
	end

	local preview_win
	local winnrs = vim.api.nvim_list_wins()
	if #winnrs == 1 then
		-- If there are no other windows, split a new one for the preview
		preview_win = vim.api.nvim_open_win(vim.api.nvim_create_buf(true, true), false, { split = "below" })
	else
		-- If there is already a window for this file, use it
		preview_win = vim.iter(winnrs):find(function(winnr)
			local fbuf = vim.fn.bufadd(error.filename.value)
			local winbuf = vim.api.nvim_win_get_buf(winnr)
			return fbuf == winbuf
		end)
	end
	-- If we still don't have a preview window,
	-- use the first existing window that isn't the first compilation window
	if not preview_win then
		local past_first_window = false
		preview_win = vim.iter(winnrs):find(function(winnr)
			if past_first_window then
				return true
			end

			local winbuf = vim.api.nvim_win_get_buf(winnr)
			if winbuf ~= compilation_buffer then
				return true
			end

			past_first_window = true
			return false
		end)
	end

	vim.schedule(function()
		local dir = find_directory_for_line(cursor_row)
		vim.api.nvim_win_call(preview_win, function()
			utils.jump_to_error(error, dir, {})
		end)
		vim.notify("Current locus from " .. vim.fn.bufname(compilation_buffer))
	end)
end

return M
