local helpers = require("spec.test_helpers")
local assert = require("luassert")

local pwd
if vim.o.shell:match("cmd.exe$") then
	pwd = "echo %cd%"
elseif vim.o.shell:match("pwsh$") or vim.o.shell:match("powershell$") then
	pwd = "$pwd"
else
	pwd = "pwd"
end

describe(":Compile", function()
	before_each(helpers.setup_tests)

	it("should use the current working directory", function()
		local cwd = vim.fn.getcwd()
		helpers.compile({ args = pwd })
		assert.are.same({ pwd, cwd }, helpers.get_output())
	end)
end)

describe(":Recompile", function()
	before_each(helpers.setup_tests)

	it("should reuse the directory from last compilation", function()
		local old_cwd = vim.fn.getcwd()
		helpers.compile({ args = pwd })
		assert.are.same({ pwd, old_cwd }, helpers.get_output())

		vim.cmd("cd ..")
		helpers.wait()

		helpers.recompile({ args = pwd })
		assert.are.same({ pwd, old_cwd }, helpers.get_output())

		vim.cmd("cd " .. old_cwd)
		helpers.wait()
	end)
end)
