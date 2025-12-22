local helpers = require("spec.test_helpers")
local assert = require("luassert")

describe("auto_scroll functionality", function()
	it("should scroll to the bottom when auto_scroll is true", function()
		helpers.setup_tests({ 
			auto_scroll = true,
			focus_compilation_buffer = true
		})

        helpers.compile({ args = "echo line1 && echo line2 && echo line3" })
		
		local bufnr = helpers.get_compilation_bufnr()
		local winid = vim.fn.bufwinid(bufnr)
		local cursor_pos = vim.api.nvim_win_get_cursor(winid)
		local line_count = vim.api.nvim_buf_line_count(bufnr)
		
		assert.are.same(line_count, cursor_pos[1])
	end)

	it("should stay at the first line of compilation output when auto_scroll is false", function()
		helpers.setup_tests({ 
			auto_scroll = false,
			focus_compilation_buffer = true 
		})

        helpers.compile({ 
            args = "echo line1 && echo line2 && echo line3 && echo line4 && echo line5 && echo line6 && echo line7" 
        })
		
		local bufnr = helpers.get_compilation_bufnr()
		local winid = vim.fn.bufwinid(bufnr)
		local cursor_pos = vim.api.nvim_win_get_cursor(winid)
        local compile_mode_header_size = 5
		
		assert.are.same(compile_mode_header_size, cursor_pos[1])
	end)
end)
