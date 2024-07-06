local helpers = require("spec.test_helpers")

local assert = require("luassert")

describe("interrupting a compilation", function()
	before_each(function()
		helpers.setup_tests({
			ask_to_interrupt = false,
		})
	end)

	it("should show an interruption message", function()
		helpers.compile({ args = "sleep 10" })

		helpers.interrupt()

		local bufnr = helpers.get_compilation_bufnr()

		local lines = vim.api.nvim_buf_get_lines(bufnr, -2, -1, false)
		assert.is_not_nil(lines[1]:match("^Compilation interrupted at "))
	end)

	it("should make the job stop running", function()
		helpers.compile({ args = "sleep 10" })

		local id = vim.g.compile_job_id

		helpers.interrupt()

		-- the id is now invalid
		assert.are.same(0, vim.fn.jobstop(id))
	end)
end)
