local utils = require("tests.utils")

---@diagnostic disable-next-line: undefined-global
local before_each = before_each
---@diagnostic disable-next-line: undefined-global
local describe = describe
---@diagnostic disable-next-line: undefined-global
local it = it
---@type any
local assert = assert

local function get_compilation_lines(bufnr)
	return vim.api.nvim_buf_get_lines(bufnr, 3, -4, false)
end

describe(":Compile", function()
	before_each(utils.setup_tests)

	it("should run a command and create a buffer with the result", function()
		vim.cmd.Compile("echo hello world")

		local bufnr = utils.get_bufnr("*compilation*")

		utils.halt_test(30)

		local lines = get_compilation_lines(bufnr)
		local expected = { "echo hello world", "hello world" }
		assert.are.same(expected, lines)
	end)
end)

describe(":Recompile", function()
	before_each(utils.setup_tests)

	it("should rerun the latest command", function()
		vim.cmd.Compile("echo hello world")

		local bufnr = utils.get_bufnr("*compilation*")

		utils.halt_test(10)

		local expected = vim.api.nvim_buf_get_lines(bufnr, 3, -4, false)

		utils.buf_set_opt(bufnr, "modifiable", true)
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})

		local lines = get_compilation_lines(bufnr)
		assert.are_not.same(expected, lines)

		vim.cmd.Recompile()

		utils.halt_test(10)

		lines = get_compilation_lines(bufnr)
		assert.are.same(expected, lines)
	end)
end)
