local a = require("plenary.async")
local tests = a.tests
local describe = tests.describe
local it = tests.it

---@type fun(name: string, create: boolean?): integer
local get_bufnr = vim.fn.bufnr

describe(":Compile", function()
	tests.before_each(function()
		require("plugin.command")
		require("compile-mode").setup({})
	end)

	it("should run a command and create a buffer with the result", function()
		vim.cmd.Compile("echo hello world")

		local bufnr = get_bufnr("Compilation")
		local lines = vim.api.nvim_buf_get_lines(bufnr, 3, -2, false)
		print(vim.inspect(lines))
	end)
end)
