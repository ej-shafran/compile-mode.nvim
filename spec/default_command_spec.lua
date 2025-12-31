vim.ui.input = function(opts, on_confirm)
	on_confirm(opts.default)
end

local helpers = require("spec.test_helpers")
local assert = require("luassert")

local echoed = "hello world"

local function print_command(value)
	return "echo " .. (vim.o.shell:match("cmd.exe$") and value or vim.fn.shellescape(value))
end
local cmd = print_command(echoed)

describe("table as default_command", function()
	before_each(function()
		helpers.setup_tests({ default_command = { good = cmd } })
	end)

	it("should use filetype specific default_command", function()
		vim.bo.filetype = "good"
		helpers.compile()

		assert.are.same({ cmd, echoed }, helpers.get_output())
	end)
end)

describe("function as default_command", function()
	before_each(function()
		helpers.setup_tests({
			default_command = function()
				return cmd
			end,
		})
	end)

	it("should use function return value as default_command", function()
		helpers.compile()

		assert.are.same({ cmd, echoed }, helpers.get_output())
	end)
end)
