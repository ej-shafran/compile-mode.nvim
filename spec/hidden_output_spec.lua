local helpers = require("spec.test_helpers")

local assert = require("luassert")

describe("`hidden_output` option", function()
	local hide = "hello"
	local non_hide = "goodbye"

	before_each(function()
		helpers.setup_tests({
			hidden_output = "^" .. hide .. ".*",
		})
	end)

	it("should configure parts of the output not to show", function()
		helpers.compile({ args = "printf '%s\\n%s' " .. hide .. " " .. non_hide })

		local bufnr = helpers.get_compilation_bufnr()
		local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

		for _, line in ipairs(lines) do
			assert.are_not.same(line, hide)
		end

		assert.are.same(lines[#lines - 2], non_hide)
	end)
end)
