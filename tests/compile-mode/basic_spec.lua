---@diagnostic disable-next-line: undefined-global
local before_each = before_each
---@diagnostic disable-next-line: undefined-global
local describe = describe
---@diagnostic disable-next-line: undefined-global
local it = it
---@type any
local assert = assert

---@type fun(name: string, create: boolean?): integer
local get_bufnr = vim.fn.bufnr

describe(":Compile", function()
	before_each(function()
		require("plugin.command")
		require("compile-mode").setup({})
	end)

	it("should run a command and create a buffer with the result", function()
		vim.cmd.Compile("echo hello world")

		local co = coroutine.running()
		vim.defer_fn(function()
			coroutine.resume(co)
		end, 100)
		coroutine.yield(co)

		local bufnr = get_bufnr("*compilation*")

		local lines = vim.api.nvim_buf_get_lines(bufnr, 3, -4, false)
		local expected = { "echo hello world", "hello world" }
		assert.are.same(lines, expected)
	end)
end)
