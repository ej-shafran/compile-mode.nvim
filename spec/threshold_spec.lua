local compile_mode = require("compile-mode")
local helpers = require("spec.test_helpers")
local assert = require("luassert")

local info = {
	filename = "README.md",
	col = 1,
	row = 1,
	level = compile_mode.level.INFO,
}
local error = {
	filename = "CHANGELOG.md",
	col = 1,
	row = 1,
	level = compile_mode.level.ERROR,
}

describe("`error_threshold` option", function()
	describe("should ignore errors lower than the threshold", function()
		before_each(helpers.setup_tests)

		it("when jumping", function()
			helpers.compile_multiple_errors({
				helpers.ibm_error(info),
				helpers.ibm_error(error),
			})

			helpers.next_error()
			helpers.assert_at_error_locus(error)
		end)

		it("in send_to_qflist", function()
			helpers.compile_multiple_errors({
				helpers.ibm_error(info),
				helpers.ibm_error(error),
			})

			compile_mode.send_to_qflist()

			assert.are.same(1, #vim.fn.getqflist())
			vim.fn.setqflist({})
		end)

		it("in add_to_qflist", function()
			helpers.compile_multiple_errors({
				helpers.ibm_error(info),
				helpers.ibm_error(error),
			})

			compile_mode.add_to_qflist()
			assert.are.same(1, #vim.fn.getqflist())

			compile_mode.add_to_qflist()
			assert.are.same(2, #vim.fn.getqflist())

			vim.fn.setqflist({})
		end)
	end)

	describe("should be lowered based on configuration", function()
		before_each(function()
			helpers.setup_tests({ error_threshold = compile_mode.level.INFO })
		end)

		it("when jumping", function()
			helpers.compile_multiple_errors({
				helpers.ibm_error(info),
				helpers.ibm_error(error),
			})

			helpers.next_error()
			helpers.assert_at_error_locus(info)
		end)

		it("in send_to_qflist", function()
			helpers.compile_multiple_errors({
				helpers.ibm_error(info),
				helpers.ibm_error(error),
			})

			compile_mode.send_to_qflist()
			assert.are.same(2, #vim.fn.getqflist())

			vim.fn.setqflist({})
		end)

		it("in add_to_qflist", function()
			helpers.compile_multiple_errors({
				helpers.ibm_error(info),
				helpers.ibm_error(error),
			})

			compile_mode.add_to_qflist()
			assert.are.same(2, #vim.fn.getqflist())

			compile_mode.add_to_qflist()
			assert.are.same(4, #vim.fn.getqflist())

			vim.fn.setqflist({})
		end)
	end)
end)
