local utils = require("tests.utils")

---@diagnostic disable-next-line: undefined-global
local before_each = before_each
---@diagnostic disable-next-line: undefined-global
local describe = describe
---@diagnostic disable-next-line: undefined-global
local it = it
---@type any
local assert = assert

describe("interrupting a compilation", function()
	before_each(utils.setup_tests())

	it("should show an interruption message", function()
		vim.cmd("silent Compile sleep 3")
		utils.wait()

		vim.cmd("silent Compile echo hello world")
		utils.wait()

		local bufnr = vim.fn.bufnr("*compilation*")

		local lines = vim.api.nvim_buf_get_lines(bufnr, -2, -1, false)
		local expected = { "Compilation interrupted at " .. vim.fn.strftime("%a %b %e %H:%M:%S") }
		assert.are.same(expected, lines)
	end)

	it("should make the job stop running", function()
		vim.cmd("silent Compile sleep 3")
		utils.wait()

		local id = vim.g.compile_job_id
		vim.cmd("silent Compile echo hello world")
		utils.wait()

		-- assert the id is now invalid
		assert.are.same(0, vim.fn.jobstop(id))
	end)
end)
