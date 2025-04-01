local helpers = require("spec.test_helpers")
local assert = require("luassert")

local filename = "somefile"

describe("bang_expansion", function()
	before_each(function()
		helpers.setup_tests({ bang_expansion = true })
	end)

	it("should expand % in a command", function()
		vim.cmd.e(filename)
		helpers.compile({ args = "echo %" })
		assert.are.same({ "echo " .. filename, filename }, helpers.get_output())
	end)

	it("should escape properly", function()
		vim.cmd.e(filename)
		helpers.compile({ args = "echo \\%" })
		assert.are.same({ "echo %", "%" }, helpers.get_output())

		helpers.compile({ args = "echo \\\\\\\\\\%" })
		assert.are.same({ "echo \\\\%", "\\%" }, helpers.get_output())
	end)
end)
