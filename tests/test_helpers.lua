---@alias CreateError {filename: string, row: integer, col: integer}

local compile_mode = require("compile-mode")

local M = {}

---COMMANDS

---@param args string
---@param smods SMods?
function M.compile(args, smods)
	compile_mode.compile({
		args = args,
		smods = vim.tbl_extend("force", smods or {}, { silent = true }),
	})
	M.wait()
end

---@param smods SMods?
function M.recompile(smods)
	compile_mode.recompile({
		smods = vim.tbl_extend("force", smods or {}, { silent = true }),
	})
	M.wait()
end

function M.interrupt()
	compile_mode.interrupt()
	M.wait()
end

---UTILS

function M.get_compilation_bufnr()
	return vim.fn.bufnr(vim.fn.fnameescape("*compilation*"))
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
