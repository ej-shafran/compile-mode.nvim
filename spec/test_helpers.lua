---@class CreateError
---
---@field row      integer
---@field col      integer
---@field filename string

local compile_mode = require("compile-mode")
local errors = require("compile-mode.errors")
local assert = require("luassert")

local M = {}

---COMMANDS

---@param param CommandParam?
---@param disable_wait boolean?
function M.compile(param, disable_wait)
	param = param or {}

	compile_mode.compile(vim.tbl_extend("force", param, {
		smods = vim.tbl_extend("force", param.smods or {}, { silent = true }),
	}))
	if not disable_wait then
		M.wait_for_compilation()
	end
end

---@param param CommandParam?
function M.recompile(param)
	param = param or {}

	compile_mode.recompile(vim.tbl_extend("force", param, {
		smods = vim.tbl_extend("force", param.smods or {}, { silent = true }),
	}))
	M.wait_for_compilation()
end

function M.interrupt()
	compile_mode.interrupt()
	M.wait_for_interruption()
end

---@param param CommandParam?
function M.next_error(param)
	compile_mode.next_error(param)
	M.wait_ms(100)
end

function M.move_to_next_error()
	compile_mode.move_to_next_error()
	M.wait_ms(100)
end

function M.move_to_next_file()
	compile_mode.move_to_next_file()
	M.wait_ms(100)
end

---UTILS

function M.get_compilation_bufnr()
	local config = require("compile-mode.config.internal")
	return vim.fn.bufadd(config.buffer_name)
end

function M.get_output(start_line, end_line)
	start_line = start_line or 3
	end_line = end_line or -4

	local bufnr = M.get_compilation_bufnr()
	local result = vim.api.nvim_buf_get_lines(bufnr, start_line, end_line, false)
	return vim.tbl_map(function(line)
		local replaced = line:gsub("%s*\r", "")
		return replaced
	end, result)
end

---@param opts CompileModeOpts|nil
function M.setup_tests(opts)
	require("plugin.command")
	vim.g.compile_mode = vim.tbl_extend("force", { debug = true }, opts or {})
	package.loaded["compile-mode.config.internal"] = nil
end

---@param directory string
function M.change_vim_directory(directory)
	vim.cmd(("cd %s"):format(directory))
	M.wait_ms(100)
end

function M.wait_for_compilation()
	local co = coroutine.running()
	vim.api.nvim_create_autocmd("User", {
		once = true,
		pattern = "CompilationFinished",
		callback = function()
			coroutine.resume(co)
		end,
	})
	coroutine.yield(co)
end

function M.wait_for_interruption()
	local co = coroutine.running()
	vim.api.nvim_create_autocmd("User", {
		once = true,
		pattern = "CompilationInterrupted",
		callback = function()
			print("here")
			coroutine.resume(co)
		end,
	})
	coroutine.yield(co)
end

---@param ms integer
function M.wait_ms(ms)
	local co = coroutine.running()
	vim.defer_fn(function()
		coroutine.resume(co)
	end, ms)
	coroutine.yield(co)
end

---@param param CreateError
function M.maven_error(param)
	return param.filename .. ":[" .. param.row .. "," .. param.col .. "] "
end

---@param param CreateError
function M.sun_ada_error(param)
	return param.filename .. ", line " .. param.row .. ", char " .. param.col .. ":"
end

---@type CompileModeRegexpMatcher
M.typescript_regexp_matcher = {
	regex = "^\\(.\\+\\)(\\([1-9][0-9]*\\),\\([1-9][0-9]*\\)): error TS[1-9][0-9]*:",
	filename = 1,
	row = 2,
	col = 3,
}

---@param param CreateError
function M.typescript_error(param)
	return param.filename .. "(" .. param.row .. "," .. param.col .. "): error TS22: "
end

---@param error_string string
function M.compile_error(error_string)
	-- ECHO in CMD is strange :(
	local str = vim.o.shell:match("cmd.exe$") and error_string or vim.fn.shellescape(error_string)
	M.compile({ args = "echo " .. str })
end

---@param error_strings string[]
function M.compile_multiple_errors(error_strings)
	local errors_with_quotes = vim.tbl_map(function(error_string)
		return "'" .. error_string .. "'"
	end, error_strings)
	local printf_args = vim.fn.join(errors_with_quotes, " ")

	local format_strings = vim.tbl_map(function()
		return "%s"
	end, error_strings)
	local printf_fmt = vim.fn.join(format_strings, "\\n")

	M.compile({ args = "printf '" .. printf_fmt .. "' " .. printf_args })
end

function M.multi_step_command(first_step, second_step, wait_seconds)
	if vim.o.shell:match("cmd.exe$") then
		return ("echo %s&& ping 127.0.0.1 -n %d > nul && echo %s"):format(first_step, wait_seconds + 1, second_step)
	elseif vim.o.shell:match("pwsh$") or vim.o.shell:match("powershell$") then
		return ("Write-Output '%s'; Start-Sleep -Seconds %d; Write-Output '%s'"):format(
			first_step,
			wait_seconds,
			second_step
		)
	else
		return ("echo '%s' && sleep %d && echo '%s'"):format(first_step, wait_seconds, second_step)
	end
end

---@param expected CreateError
function M.assert_parsed_error(error_string, expected)
	---@type CompileModeError|nil
	local actual = nil
	for _, error in pairs(errors.error_list) do
		local full_text = error.full_text:gsub("\r", "")
		if full_text == error_string then
			actual = error
			break
		end
	end
	assert.is_not_nil(actual)
	if not actual then
		return
	end

	local full_text = actual.full_text:gsub("\r", "")
	assert.are.same(full_text, error_string)
	assert.are.same(actual.filename.value, expected.filename)
	assert.are.same(actual.row.value, expected.row)
	assert.are.same(actual.col.value, expected.col)
end

---@param expected CreateError
function M.assert_at_error_locus(expected)
	local actual_filename = vim.fn.expand("%:t")
	assert.are.same(actual_filename, expected.filename)
	local actual_row, actual_col = unpack(vim.api.nvim_win_get_cursor(0))
	assert.are.same(actual_row, expected.row)
	assert.are.same(actual_col + 1, expected.col)
end

---@param error_string string
function M.assert_cursor_at_error(error_string)
	---@type integer|nil
	local line = nil
	for i, error in pairs(errors.error_list) do
		local full_text = error.full_text:gsub("\r", "")
		if full_text == error_string then
			line = i
		end
	end
	assert.is_not_nil(line)

	local actual_row = unpack(vim.api.nvim_win_get_cursor(0))
	assert.are.same(actual_row, line)
end

return M
