local helpers = require("spec.test_helpers")
local assert = require("luassert")

local echoed = "hello world"

describe("carriage return in command", function()
	before_each(helpers.setup_tests)

	it("should have no effect at the end of the line", function()
		local cmd = ([[printf '%s\r\n']]):format(echoed)

		helpers.compile({ args = cmd })

		assert.are.same({ cmd, echoed }, helpers.get_output())
	end)

	it("should have no effect at the end of the line (multiple)", function()
		local cmd = ([[printf '%s\r\r\r\n']]):format(echoed)

		helpers.compile({ args = cmd })

		assert.are.same({ cmd, echoed }, helpers.get_output())
	end)

	it("should clear to the start of the line", function()
		local cmd = ([[printf 'Hello, world!\r%s\n']]):format(echoed)

		helpers.compile({ args = cmd })

		assert.are.same({ cmd, echoed }, helpers.get_output())
	end)

	it([[should work with other escape characters (e.g. \e[K)]], function()
		local cmd = ([[printf 'Hello, world!\r\e[K%s\n']]):format(echoed)

		helpers.compile({ args = cmd })

		assert.are.same({ cmd, "\27[K" .. echoed }, helpers.get_output())
	end)
end)
