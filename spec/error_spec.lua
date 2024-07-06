local helpers = require("spec.test_helpers")

describe("error parsing", function()
	before_each(function()
		helpers.setup_tests({
			error_regexp_table = {
				typescript = helpers.typescript_regexp_matcher,
			},
		})
	end)

	it("should find errors using the default regexes", function()
		---@type CreateError
		local expected = {
			filename = "README.md",
			row = 1,
			col = 1,
		}
		local error_string = helpers.maven_error(expected)

		helpers.compile_error(error_string)

		helpers.assert_parsed_error(error_string, expected)
	end)

	it("should use custom regexes", function()
		---@type CreateError
		local expected = {
			filename = "path/to/error-file.ts",
			row = 13,
			col = 23,
		}
		local error_string = helpers.typescript_error(expected)

		helpers.compile_error(error_string)

		helpers.assert_parsed_error(error_string, expected)
	end)
end)

describe("jumping to errors", function()
	before_each(helpers.setup_tests)

	it("should jump to an error's locus", function()
		---@type CreateError
		local expected = {
			filename = "README.md",
			row = 1,
			col = 1,
		}
		local error_string = helpers.sun_ada_error(expected)

		helpers.compile_error(error_string)
		helpers.next_error()

		helpers.assert_at_error_locus(expected)
	end)
end)

describe("moving to errors", function()
	before_each(helpers.setup_tests)

	it("should move to an error's location in the compilation buffer", function()
		---@type CreateError
		local expected = {
			filename = "README.md",
			row = 1,
			col = 1,
		}
		local error_string = helpers.sun_ada_error(expected)

		helpers.compile_error(error_string)
		helpers.move_to_next_error()

		helpers.assert_cursor_at_error(error_string)
	end)
end)
