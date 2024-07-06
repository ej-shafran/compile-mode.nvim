local helpers = require("spec.test_helpers")

local assert = require("luassert")

describe("`auto_jump_to_first_error` option", function()
	before_each(function()
		helpers.setup_tests({ auto_jump_to_first_error = true })
	end)

	it("should jump the moment an error is available", function()
		local filename = "README.md"
		local row = 1
		local col = 1
		local error_string = helpers.sun_ada_error({ filename = filename, row = row, col = col })

		helpers.compile({ args = "echo '" .. error_string .. "'" })

		local actual_filename = vim.fn.expand("%:t")
		assert.are.same(actual_filename, filename)
		local actual_row, actual_col = unpack(vim.api.nvim_win_get_cursor(0))
		assert.are.same(actual_row, row)
		assert.are.same(actual_col + 1, col)
	end)
end)
