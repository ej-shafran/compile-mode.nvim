local utils = require("tests.test_helpers")

---@diagnostic disable-next-line: undefined-global
local before_each = before_each
---@diagnostic disable-next-line: undefined-global
local describe = describe
---@diagnostic disable-next-line: undefined-global
local it = it
---@type any
local assert = assert

describe("the `compilation_hidden_output` option", function()
	before_each(function()
		utils.setup_tests({
			compilation_hidden_output = "^hello.*",
		})
	end)

	it("should configure parts of the output not to show", function()
		vim.cmd('silent Compile echo -e "hello world\\nhow are yout"')

		local bufnr = utils.get_compilation_bufnr()

		utils.wait()

		local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

		for _, line in ipairs(lines) do
			assert.are_not.same(line, "hello world")
		end
	end)
end)
