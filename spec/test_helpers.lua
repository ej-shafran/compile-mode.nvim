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
function M.compile(param)
	param = param or {}

	compile_mode.compile(vim.tbl_extend("force", param, {
		smods = vim.tbl_extend("force", param.smods or {}, { silent = true }),
	}))
	M.wait()
end

---@param param CommandParam?
function M.recompile(param)
	param = param or {}

	compile_mode.recompile(vim.tbl_extend("force", param, {
		smods = vim.tbl_extend("force", param.smods or {}, { silent = true }),
	}))
	M.wait()
end

function M.interrupt()
	compile_mode.interrupt()
	M.wait()
end

---@param param CommandParam?
function M.next_error(param)
	compile_mode.next_error(param)
	M.wait()
end

function M.move_to_next_error()
	compile_mode.move_to_next_error()
	M.wait()
end

function M.move_to_next_file()
	compile_mode.move_to_next_file()
	M.wait()
end

---UTILS

function M.get_compilation_bufnr()
	local config = require("compile-mode.config.internal")
	return vim.fn.bufadd(config.buffer_name)
end

function M.get_output()
	local bufnr = M.get_compilation_bufnr()
	local result = vim.api.nvim_buf_get_lines(bufnr, 3, -4, false)
	return vim.tbl_map(function(line)
		local replaced = line:gsub("\r", "")
		return replaced
	end, result)
end

---@param opts CompileModeOpts|nil
function M.setup_tests(opts)
	require("plugin.command")
	vim.g.compile_mode = vim.tbl_extend("force", { debug = true }, opts or {})
	package.loaded["compile-mode.config.internal"] = nil
end

function M.wait()
	local co = coroutine.running()
	vim.defer_fn(function()
		coroutine.resume(co)
	end, 100)
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

---@param expected CreateError
function M.assert_parsed_error(error_string, expected)
	print(vim.inspect(M.get_output()))
	print(vim.inspect(errors.error_list))

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
