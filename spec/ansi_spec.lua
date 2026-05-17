-- /home/klevis/Projects/compile-mode.nvim/spec/ansi_spec.lua
local helpers = require("spec.test_helpers")
local assert = require("luassert")

describe("ANSI escape sequence handling", function()
	describe("filter mode", function()
		before_each(function()
			helpers.setup_tests({
				ansi_color_for_compilation = "filter",
			})
		end)

		it("strips CSI non-SGR sequences", function()
			local cmd = [[printf 'hello\e[1Aworld\n']]
			helpers.compile({ args = cmd })

			local output = helpers.get_output()
			assert.are.same({ cmd, "helloworld" }, output)
		end)

		it("strips SGR sequences", function()
			local cmd = [[printf 'hello\e[31mworld\n']]
			helpers.compile({ args = cmd })

			local output = helpers.get_output()
			assert.are.same({ cmd, "helloworld" }, output)
		end)

		it("strips OSC sequences with BEL terminator", function()
			local cmd = [[printf 'hello\e]2;mytitle\aworld\n']]
			helpers.compile({ args = cmd })

			local output = helpers.get_output()
			assert.are.same({ cmd, "helloworld" }, output)
		end)

		it("strips OSC sequences with ST terminator", function()
			local cmd = [[printf 'hello\e]2;mytitle\e\\world\n']]
			helpers.compile({ args = cmd })

			local output = helpers.get_output()
			assert.are.same({ cmd, "helloworld" }, output)
		end)

		it("strips mixed CSI + OSC + SGR sequences", function()
			local cmd = [[printf '\e[31m\e]2;title\ahello\e[1Aworld\n']]
			helpers.compile({ args = cmd })

			local output = helpers.get_output()
			assert.are.same({ cmd, "helloworld" }, output)
		end)

		it("passes plain text through unchanged", function()
			local cmd = "echo 'hello world'"
			helpers.compile({ args = cmd })

			local output = helpers.get_output()
			assert.are.same({ cmd, "hello world" }, output)
		end)

		it("strips multiple CSI sequences on one line", function()
			local cmd = [[printf '\e[1A\e[K\e[31mhello\e[0m\n']]
			helpers.compile({ args = cmd })

			local output = helpers.get_output()
			assert.are.same({ cmd, "hello" }, output)
		end)

		it("strips line that is only escape sequences", function()
			local cmd = [[printf '\e[31m\e[0m\n']]
			helpers.compile({ args = cmd })

			local output = helpers.get_output()
			assert.are.same({ cmd, "" }, output)
		end)
	end)
end)

describe("passthrough mode", function()
	before_each(function()
		helpers.setup_tests({
			ansi_color_for_compilation = "passthrough",
		})
	end)

	it("leaves CSI sequences in buffer as-is", function()
		local cmd = [[printf 'hello\e[1Aworld\n']]
		helpers.compile({ args = cmd })

		local output = helpers.get_output()
		assert.are.same({ cmd, "hello\27[1Aworld" }, output)
	end)

	it("leaves OSC sequences in buffer as-is", function()
		local cmd = [[printf 'hello\e]2;title\aworld\n']]
		helpers.compile({ args = cmd })

		local output = helpers.get_output()
		-- BEL (0x07) appears as \7, ESC as \27
		assert.are.same({ cmd, "hello\27]2;title\7world" }, output)
	end)

	it("leaves SGR sequences in buffer as-is", function()
		local cmd = [[printf '\e[31mhello\e[0m\n']]
		helpers.compile({ args = cmd })

		local output = helpers.get_output()
		assert.are.same({ cmd, "\27[31mhello\27[0m" }, output)
	end)
end)

describe("partial sequence buffering", function()
	local ansi

	before_each(function()
		helpers.setup_tests({ ansi_color_for_compilation = "filter" })
		ansi = require("compile-mode.ansi")
	end)
	it("buffers incomplete CSI at end of chunk", function()
		local bufnr = vim.api.nvim_create_buf(false, true)

		ansi.buf_set_lines(bufnr, 0, -1, { "hello\27[" })
		ansi.buf_set_lines(bufnr, -1, -1, { "1Aworld" })

		local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
		assert.are.same({ "hello", "world" }, lines)

		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	it("buffers incomplete OSC at end of chunk", function()
		local bufnr = vim.api.nvim_create_buf(false, true)

		ansi.buf_set_lines(bufnr, 0, -1, { "hello\27]2;tit" })
		ansi.buf_set_lines(bufnr, -1, -1, { "le\7world" })

		local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
		assert.are.same({ "hello", "world" }, lines)

		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	it("buffers lone ESC at end of chunk", function()
		local bufnr = vim.api.nvim_create_buf(false, true)

		ansi.buf_set_lines(bufnr, 0, -1, { "hello\27" })
		ansi.buf_set_lines(bufnr, -1, -1, { "[1Aworld" })

		local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
		assert.are.same({ "hello", "world" }, lines)

		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	it("reassembles multiple chunks correctly", function()
		local bufnr = vim.api.nvim_create_buf(false, true)

		ansi.buf_set_lines(bufnr, 0, -1, { "line1" })
		ansi.buf_set_lines(bufnr, -1, -1, { "line\27[31m2" })
		ansi.buf_set_lines(bufnr, -1, -1, { "\27[0m" })

		local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
		assert.are.same({ "line1", "line2", "" }, lines)

		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	it("reassembles across 3 chunks", function()
		local bufnr = vim.api.nvim_create_buf(false, true)

		ansi.buf_set_lines(bufnr, 0, -1, { "hello\27" })
		ansi.buf_set_lines(bufnr, -1, -1, { "[" })
		ansi.buf_set_lines(bufnr, -1, -1, { "1Aworld" })

		local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
		assert.are.same({ "hello", "", "world" }, lines)

		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	it("handles complete sequence followed by partial at end", function()
		local bufnr = vim.api.nvim_create_buf(false, true)

		ansi.buf_set_lines(bufnr, 0, -1, { "hello\27[1A\27[" })
		ansi.buf_set_lines(bufnr, -1, -1, { "31m" })
		ansi.buf_set_lines(bufnr, -1, -1, { "world" })

		local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
		assert.are.same({ "hello", "", "world" }, lines)

		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	it("buffers incomplete OSC at end of chunk with ST terminator", function()
		local bufnr = vim.api.nvim_create_buf(false, true)

		ansi.buf_set_lines(bufnr, 0, -1, { "hello\27]2;tit" })
		ansi.buf_set_lines(bufnr, -1, -1, { "le\27\\world" })

		local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
		assert.are.same({ "hello", "world" }, lines)

		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	it("handles entire line being a partial sequence", function()
		local bufnr = vim.api.nvim_create_buf(false, true)

		ansi.buf_set_lines(bufnr, 0, -1, { "\27[" })
		ansi.buf_set_lines(bufnr, -1, -1, { "1Ahello" })

		local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
		assert.are.same({ "", "hello" }, lines)

		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	it("flushes remaining partial buffer on process exit", function()
		local bufnr = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "make -k ", "" })

		ansi.buf_set_lines(bufnr, -2, -1, { "hello\27[" })
		ansi.flush(bufnr)

		local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
		assert.are.same({ "make -k ", "hello\27[" }, lines)

		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)
end)

describe("OSC handlers", function()
	it("default handlers are no-ops", function()
		helpers.setup_tests({
			ansi_color_for_compilation = "filter",
		})

		-- Should not crash or produce side effects
		local cmd = [[printf '\e]2;mytitle\a\e]7;file:///tmp\a\e]0;iconname\ahello\n']]
		helpers.compile({ args = cmd })

		local output = helpers.get_output()
		assert.are.same({ cmd, "hello" }, output)
	end)

	it("custom handler for command 2 receives title data", function()
		local received_data = nil

		helpers.setup_tests({
			ansi_color_for_compilation = "filter",
			osc_handlers = {
				[2] = function(data)
					received_data = data
					return ""
				end,
			},
		})

		local cmd = [[printf '\e]2;my window title\ahello\n']]
		helpers.compile({ args = cmd })

		assert.are.same("my window title", received_data)
		local output = helpers.get_output()
		assert.are.same({ cmd, "hello" }, output)
	end)

	it("custom handler for command 7 receives cwd data", function()
		local received_data = nil

		helpers.setup_tests({
			ansi_color_for_compilation = "filter",
			osc_handlers = {
				[7] = function(data)
					received_data = data
					return ""
				end,
			},
		})

		local cmd = [[printf '\e]7;file:///home/user\ahello\n']]
		helpers.compile({ args = cmd })

		assert.are.same("file:///home/user", received_data)
	end)

	it("unknown OSC command is stripped with no handler call", function()
		local handler_called = false

		helpers.setup_tests({
			ansi_color_for_compilation = "filter",
			osc_handlers = {
				[99] = function(_)
					handler_called = true
					return ""
				end,
			},
		})

		-- OSC 99 is not in default handlers, but user added one
		local cmd = [[printf '\e]99;customdata\ahello\n']]
		helpers.compile({ args = cmd })

		assert.is_true(handler_called)
		local output = helpers.get_output()
		assert.are.same({ cmd, "hello" }, output)
	end)

	it("OSC 8 hyperlink with params renders URI visible", function()
		helpers.setup_tests({
			ansi_color_for_compilation = "filter",
		})

		local cmd = [[printf '\e]8;id=123;https://example.com\e\\click here\e]8;;\e\\\n']]
		helpers.compile({ args = cmd })

		local output = helpers.get_output()
		-- Should show the URI from the first OSC 8, and the close tag is stripped
		assert.are.same({ cmd, "https://example.com click here" }, output)
	end)

	it("OSC 8 hyperlink with empty params renders URI visible", function()
		helpers.setup_tests({
			ansi_color_for_compilation = "filter",
		})

		local cmd = [[printf '\e]8;;https://example.com\e\\click here\e]8;;\e\\\n']]
		helpers.compile({ args = cmd })

		local output = helpers.get_output()
		assert.are.same({ cmd, "https://example.com click here" }, output)
	end)

	it("OSC 8 hyperlink with URI containing semicolons renders full URI", function()
		helpers.setup_tests({
			ansi_color_for_compilation = "filter",
		})

		local cmd = [[printf '\e]8;;https://example.com/path?a=1;b=2\e\\link\e]8;;\e\\\n']]
		helpers.compile({ args = cmd })

		local output = helpers.get_output()
		assert.are.same({ cmd, "https://example.com/path?a=1;b=2 link" }, output)
	end)

	it("handler return value replaces the OSC sequence in buffer", function()
		helpers.setup_tests({
			ansi_color_for_compilation = "filter",
			osc_handlers = {
				[2] = function(_)
					return "[TITLE]"
				end,
			},
		})

		local cmd = [[printf 'hello\e]2;mytitle\aworld\n']]
		helpers.compile({ args = cmd })

		local output = helpers.get_output()
		assert.are.same({ cmd, "hello[TITLE]world" }, output)
	end)

	it("handler returning empty string strips the sequence entirely", function()
		helpers.setup_tests({
			ansi_color_for_compilation = "filter",
			osc_handlers = {
				[2] = function(_)
					return ""
				end,
			},
		})

		local cmd = [[printf 'hello\e]2;mytitle\aworld\n']]
		helpers.compile({ args = cmd })

		local output = helpers.get_output()
		assert.are.same({ cmd, "helloworld" }, output)
	end)

	it("handlers fire in filter mode", function()
		local fired = false

		helpers.setup_tests({
			ansi_color_for_compilation = "filter",
			osc_handlers = {
				[2] = function(_)
					fired = true
					return ""
				end,
			},
		})

		local cmd = [[printf '\e]2;title\ahello\n']]
		helpers.compile({ args = cmd })

		assert.is_true(fired)
	end)
end)

describe("fallback behavior", function()
	it("falls back to filter when baleia is unavailable and mode is render", function()
		-- Temporarily hide baleia so require("baleia") fails
		package.loaded["baleia"] = nil
		local original = package.searchers
		-- Ensure baleia can't be found
		package.searchers = {
			function(name)
				if name == "baleia" then
					return nil, "module not found"
				end
				for i = 1, #original do
					local result = { original[i](name) }
					if result[1] then
						return unpack(result)
					end
				end
				return nil, "module not found"
			end,
		}

		helpers.setup_tests({
			ansi_color_for_compilation = "render",
		})

		local cmd = [[printf '\e[31mhello\e[0m\e]2;title\aworld\n']]
		helpers.compile({ args = cmd })

		-- Should behave like filter: all stripped
		local output = helpers.get_output()
		assert.are.same({ cmd, "helloworld" }, output)

		package.searchers = original
	end)
end)

describe("partial buffering integration", function()
	local ansi

	before_each(function()
		helpers.setup_tests({ ansi_color_for_compilation = "filter" })
		ansi = require("compile-mode.ansi")
	end)

	it("works with replace semantics (-2, -1) like real pipeline", function()
		local bufnr = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "make -k ", "" })

		ansi.buf_set_lines(bufnr, -2, -1, { "hello\27[" })
		ansi.buf_set_lines(bufnr, -2, -1, { "1Aworld" })

		local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
		assert.are.same({ "make -k ", "world" }, lines)

		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)
end)
