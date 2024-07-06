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

	it("should skip ahead by a count", function()
		---@type CreateError
		local expected = {
			filename = "README.md",
			row = 1,
			col = 1,
		}
		local errors = {
			helpers.sun_ada_error({ filename = "todos.org", row = 1, col = 1 }),
			helpers.sun_ada_error({ filename = "todos.org", row = 2, col = 1 }),
			helpers.sun_ada_error(expected),
		}

		helpers.compile_multiple_errors(errors)

		helpers.next_error({ count = 3 })

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

	it("should skip to another file if specified", function()
		local first_file = "todos.org"
		local second_file = "README.md"
		local errors = {
			helpers.sun_ada_error({ filename = first_file, row = 1, col = 1 }),
			helpers.sun_ada_error({ filename = first_file, row = 2, col = 1 }),

			helpers.sun_ada_error({ filename = second_file, row = 1, col = 1 }),
		}

		helpers.compile_multiple_errors(errors)

		helpers.move_to_next_error()
		helpers.assert_cursor_at_error(errors[1])

		helpers.move_to_next_file()
		helpers.assert_cursor_at_error(errors[3])
	end)
end)
