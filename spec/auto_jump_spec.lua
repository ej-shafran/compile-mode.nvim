local helpers = require("spec.test_helpers")

describe("`auto_jump_to_first_error` option", function()
	before_each(function()
		helpers.setup_tests({ auto_jump_to_first_error = true })
	end)

	it("should jump the moment an error is available", function()
		---@type CreateError
		local expected = {
			filename = "README.md",
			row = 1,
			col = 1,
		}
		local error_string = helpers.sun_ada_error(expected)

		helpers.compile_error(error_string)

		helpers.assert_at_error_locus(expected)
	end)
end)
