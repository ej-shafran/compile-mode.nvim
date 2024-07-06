local helpers = require("spec.test_helpers")
local errors = require("compile-mode.errors")

local assert = require("luassert")

---@param error_string string
local function compile_error(error_string)
	helpers.compile({ args = "echo '" .. error_string .. "'" })
end

---@param expected CreateError
local function assert_parsed_error(error_string, expected)
	local actual = errors.error_list[5]
	assert.are.same(actual.full_text, error_string)
	assert.are.same(actual.filename.value, expected.filename)
	assert.are.same(actual.row.value, expected.row)
	assert.are.same(actual.col.value, expected.col)
end

---@param expected CreateError
local function assert_at_error_locus(expected)
	local actual_filename = vim.fn.expand("%:t")
	assert.are.same(actual_filename, expected.filename)
	local actual_row, actual_col = unpack(vim.api.nvim_win_get_cursor(0))
	assert.are.same(actual_row, expected.row)
	assert.are.same(actual_col + 1, expected.col)
end

---@param error_string string
local function assert_cursor_at_error(error_string)
	---@type integer|nil
	local line = nil
	for i, error in pairs(errors.error_list) do
		if error.full_text == error_string then
			line = i
		end
	end
	assert.is_not_nil(line)

	local actual_row = unpack(vim.api.nvim_win_get_cursor(0))
	assert.are.same(actual_row, line)
end

describe("error parsing", function()
	it("should find errors using the default regexes", function()
		helpers.setup_tests()

		---@type CreateError
		local expected = {
			filename = "README.md",
			row = 1,
			col = 1,
		}
		local error_string = helpers.maven_error(expected)

		compile_error(error_string)

		assert_parsed_error(error_string, expected)
	end)

	it("should use custom regexes", function()
		helpers.setup_tests({
			error_regexp_table = {
				typescript = helpers.typescript_regexp_matcher,
			},
		})

		---@type CreateError
		local expected = {
			filename = "path/to/error-file.ts",
			row = 13,
			col = 23,
		}
		local error_string = helpers.typescript_error(expected)

		compile_error(error_string)

		assert_parsed_error(error_string, expected)
	end)
end)

describe("jumping to errors", function()
	it("should jump to an error's locus", function()
		helpers.setup_tests()

		---@type CreateError
		local expected = {
			filename = "README.md",
			row = 1,
			col = 1,
		}
		local error_string = helpers.sun_ada_error(expected)

		compile_error(error_string)
		helpers.next_error()

		assert_at_error_locus(expected)
	end)
end)

describe("moving to errors", function()
	it("should move to an error's location in the compilation buffer", function()
		helpers.setup_tests()

		---@type CreateError
		local expected = {
			filename = "README.md",
			row = 1,
			col = 1,
		}
		local error_string = helpers.sun_ada_error(expected)

		compile_error(error_string)
		helpers.move_to_next_error()

		assert_cursor_at_error(error_string)
	end)
end)
