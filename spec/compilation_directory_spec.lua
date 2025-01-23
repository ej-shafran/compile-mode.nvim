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

	it("should use vim.g.compilation_directory if set", function()
		local dir = "/"
		vim.g.compilation_directory = dir

		helpers.compile({ args = pwd })
		assert.are.same({ pwd, dir }, helpers.get_output())
	end)

	it("should unset vim.g.compilation_directory", function()
		vim.g.compilation_directory = "/"

		helpers.compile({ args = pwd })
		assert.is_nil(vim.g.compilation_directory)
	end)
end)

describe(":Recompile", function()
	before_each(helpers.setup_tests)

	it("should reuse the directory from last compilation", function()
		local old_cwd = vim.fn.getcwd()
		helpers.compile({ args = pwd })
		assert.are.same({ pwd, old_cwd }, helpers.get_output())

		-- Over the current working directory
		helpers.change_vim_directory("..")
		helpers.recompile({ args = pwd })
		assert.are.same({ pwd, old_cwd }, helpers.get_output())
		helpers.change_vim_directory(old_cwd)

		-- Over vim.g.compilation_directory
		vim.g.compilation_directory = "/"
		helpers.recompile({ args = pwd })
		assert.are.same({ pwd, old_cwd }, helpers.get_output())
		vim.g.compilation_directory = nil
	end)
end)
