local helpers = require("spec.test_helpers")
local assert = require("luassert")

describe("max_lines", function()
	before_each(function()
		helpers.setup_tests({
			max_lines = 8,
		})
	end)

	it("should stop the process when the output reaches the limit", function()
		local output = {
			helpers.sun_ada_error({ filename = "README.md", row = 1, col = 1 }),
			helpers.sun_ada_error({ filename = "README.md", row = 2, col = 1 }),
			helpers.sun_ada_error({ filename = "README.md", row = 3, col = 1 }),
			helpers.sun_ada_error({ filename = "README.md", row = 4, col = 1 }),
			helpers.sun_ada_error({ filename = "README.md", row = 5, col = 1 }),
			helpers.sun_ada_error({ filename = "README.md", row = 6, col = 1 }),
			helpers.sun_ada_error({ filename = "README.md", row = 7, col = 1 }),
			helpers.sun_ada_error({ filename = "README.md", row = 8, col = 1 }),
			helpers.sun_ada_error({ filename = "README.md", row = 9, col = 1 }),
		}

		helpers.compile_multiple_errors(output)

		local bufnr = helpers.get_compilation_bufnr()
		local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
		assert.are.same(143, vim.g.compilation_exit_code)
		assert.is_false(vim.tbl_contains(lines, output[9]))
		assert.is_true(vim.iter(lines):any(function(line)
			return vim.startswith(line, "Compilation terminated: max_lines reached at ")
		end))
	end)
end)
