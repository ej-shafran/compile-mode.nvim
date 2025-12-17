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

	it("should not error when in the unsaved file being jumped to", function()
		---@type CreateError
		local expected = {
			filename = "README.md",
			row = 1,
			col = 1,
		}
		local errors = {
			helpers.sun_ada_error(expected),
			helpers.sun_ada_error(expected),
		}

		helpers.compile_multiple_errors(errors)

		helpers.next_error()

		vim.bo.modified = true

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

describe("circular error navigation", function()
	before_each(function()
		helpers.setup_tests({
			use_circular_error_navigation = true,
		})
	end)

	it("should wrap from last to first error with NextError", function()
		local first = { filename = "README.md", row = 1, col = 1 }
		local second = { filename = "todos.org", row = 1, col = 1 }
		local errors = {
			helpers.sun_ada_error(first),
			helpers.sun_ada_error(second),
		}

		helpers.compile_multiple_errors(errors)

		helpers.next_error()
		helpers.assert_at_error_locus(first)

		helpers.next_error()
		helpers.assert_at_error_locus(second)

		helpers.next_error()
		helpers.assert_at_error_locus(first)
	end)

	it("should wrap from first to last error with PrevError", function()
		local first = { filename = "README.md", row = 1, col = 1 }
		local second = { filename = "todos.org", row = 1, col = 1 }
		local errors = {
			helpers.sun_ada_error(first),
			helpers.sun_ada_error(second),
		}

		helpers.compile_multiple_errors(errors)

		helpers.next_error()
		helpers.assert_at_error_locus(first)

		helpers.prev_error()
		helpers.assert_at_error_locus(second)
	end)

	it("should respect count when wrapping", function()
		local first = { filename = "README.md", row = 1, col = 1 }
		local second = { filename = "todos.org", row = 1, col = 1 }
		local third = { filename = "LICENSE", row = 1, col = 1 }
		local errors = {
			helpers.sun_ada_error(first),
			helpers.sun_ada_error(second),
			helpers.sun_ada_error(third),
		}

		helpers.compile_multiple_errors(errors)

		helpers.next_error()
		helpers.assert_at_error_locus(first)

		helpers.next_error({ count = 4 })
		helpers.assert_at_error_locus(second)
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

		vim.api.nvim_set_current_buf(helpers.get_compilation_bufnr())

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

		vim.api.nvim_set_current_buf(helpers.get_compilation_bufnr())

		helpers.move_to_next_error()
		helpers.assert_cursor_at_error(errors[1])

		helpers.move_to_next_file()
		helpers.assert_cursor_at_error(errors[3])
	end)
end)
