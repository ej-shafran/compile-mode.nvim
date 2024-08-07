local helpers = require("spec.test_helpers")
local assert = require("luassert")

local echoed = "hello world"
local cmd = "echo " .. echoed

describe(":Compile", function()
	before_each(helpers.setup_tests)

	it("should run a command and create a buffer with the result", function()
		helpers.compile({ args = cmd })

		assert.are.same({ cmd, echoed }, helpers.get_output())
	end)
end)

describe(":Recompile", function()
	before_each(helpers.setup_tests)

	it("should rerun the latest command", function()
		helpers.compile({ args = cmd })

		local expected = helpers.get_output()
		helpers.recompile()

		assert.are.same(expected, helpers.get_output())
	end)
end)
