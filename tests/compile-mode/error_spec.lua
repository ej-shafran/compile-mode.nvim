local utils = require("tests.test_helpers")
local errors = require("compile-mode.errors")

local assert = require("luassert")

describe("error parsing", function()
	it("should find errors using the default regexes", function()
		utils.setup_tests()

		local filename = "README.md"
		local row = 1
		local col = 1
		local error_string = utils.maven_error({ filename = filename, row = row, col = col })

		utils.compile("echo '" .. error_string .. "'")

		local actual = errors.error_list[5]
		assert.are.same(actual.full_text, error_string)
		assert.are.same(actual.filename.value, filename)
		assert.are.same(actual.row.value, row)
		assert.are.same(actual.col.value, col)
	end)

	it("should use custom regexes", function()
		utils.setup_tests({
			error_regexp_table = {
				typescript = utils.typescript_regexp_matcher,
			},
		})

		local filename = "path/to/error-file.ts"
		local row = 13
		local col = 23
		local error_string = utils.typescript_error({ filename = filename, row = row, col = col })

		utils.compile("echo '" .. error_string .. "'")
		utils.wait()

		local actual = errors.error_list[5]
		assert.are.same(actual.full_text, error_string)
		assert.are.same(actual.filename.value, filename)
		assert.are.same(actual.row.value, row)
		assert.are.same(actual.col.value, col)
	end)
end)
