local helpers = require("spec.test_helpers")
local assert = require("luassert")

local expected = "hello world"
local cmd = "printf 'hello\\0 world\\n'"

describe("printing nul bytes", function()
	before_each(helpers.setup_tests)

	it("should properly remove the bytes", function()
		helpers.compile({ args = cmd })

		assert.are.same({ cmd, expected }, helpers.get_output())
	end)
end)
