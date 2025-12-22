local helpers = require("spec.test_helpers")
local assert = require("luassert")

local filename = "somefile"

local function print_command(value)
	return "echo " .. (vim.o.shell:match("cmd.exe$") and value or vim.fn.shellescape(value))
end

describe("bang_expansion", function()
	before_each(function()
		helpers.setup_tests({ bang_expansion = true })
	end)

	it("should expand % in a command", function()
		vim.cmd.e(filename)
		helpers.compile({ args = print_command("%") })
		assert.are.same({ print_command(filename), filename }, helpers.get_output())
	end)

	it("should escape properly", function()
		vim.cmd.e(filename)
		helpers.compile({ args = print_command([[\%]]) })
		assert.are.same({ print_command("%"), "%" }, helpers.get_output())
	end)
end)

describe("expansion with focus_compilation_buffer", function()
	before_each(function()
		helpers.setup_tests({ 
			bang_expansion = true,
			focus_compilation_buffer = true 
		})
	end)

	it("should expand % to the source file even when focusing the compilation buffer", function()
		vim.cmd.e(filename)
		
		helpers.compile({ args = print_command("%") })
		
		assert.are.same({ print_command(filename), filename }, helpers.get_output())
		
		local config = require("compile-mode.config.internal")
		assert.are.same(config.buffer_name, vim.fn.expand("%:t"))
	end)
end)
