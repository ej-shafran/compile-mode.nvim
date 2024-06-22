local helpers = require("tests.test_helpers")
local assert = require("luassert")

local function get_output()
	local bufnr = helpers.get_compilation_bufnr()
	return vim.api.nvim_buf_get_lines(bufnr, 3, -4, false)
end

local echoed = "hello world"
local cmd = "echo " .. echoed

describe(":Compile", function()
	before_each(helpers.setup_tests)

	it("should run a command and create a buffer with the result", function()
		helpers.compile(cmd)

		assert.are.same({ cmd, echoed }, get_output())
	end)
end)

describe(":Recompile", function()
	before_each(helpers.setup_tests)

	it("should rerun the latest command", function()
		helpers.compile(cmd)

		local expected = get_output()
		helpers.recompile()

		assert.are.same(expected, get_output())
	end)
end)
