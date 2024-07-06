---@alias CreateError {filename: string, row: integer, col: integer}

local compile_mode = require("compile-mode")

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

function M.next_error()
	compile_mode.next_error()
	M.wait()
end

function M.move_to_next_error()
	compile_mode.move_to_next_error()
	M.wait()
end

---UTILS

function M.get_compilation_bufnr()
	return vim.fn.bufnr(vim.fn.fnameescape("*compilation*"))
end

function M.get_output()
	local bufnr = M.get_compilation_bufnr()
	return vim.api.nvim_buf_get_lines(bufnr, 3, -4, false)
end

---@param opts Config|nil
function M.setup_tests(opts)
	require("plugin.command")
	require("compile-mode").setup(opts or {})
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

---@type RegexpMatcher
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

return M
