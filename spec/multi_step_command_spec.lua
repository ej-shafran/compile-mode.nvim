local helpers = require("spec.test_helpers")
local assert = require("luassert")

local first_step_output = "hello"
local wait_seconds = 1
local second_step_output = "goodbye"
local cmd = ("echo %s && %s && echo %s"):format(
	first_step_output,
	helpers.sleep_command(wait_seconds),
	second_step_output
)

describe("multi step command", function()
	before_each(helpers.setup_tests)

	it("should output the command step-by-step", function()
		helpers.compile({ args = cmd })
		assert.are.same({ cmd, first_step_output }, helpers.get_output(nil, -2))
		helpers.wait(wait_seconds * 1000 + 100)
		assert.are.same({ cmd, first_step_output, second_step_output }, helpers.get_output())
	end)
end)
