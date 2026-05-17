-- /home/klevis/Projects/compile-mode.nvim/spec/ansi_spec.lua
local helpers = require("spec.test_helpers")
local assert = require("luassert")

local function assert_output(cmd, expected)
	helpers.compile({ args = cmd })
	local output = helpers.get_output()
	assert.are.same(vim.list_extend({ cmd }, expected), output)
end

local function assert_buffer(lines_list, expected)
	local bufnr = vim.api.nvim_create_buf(false, true)
	local ansi = require("compile-mode.ansi")
	for i, lines in ipairs(lines_list) do
		if i == 1 then
			ansi.buf_set_lines(bufnr, 0, -1, lines)
		else
			ansi.buf_set_lines(bufnr, -1, -1, lines)
		end
	end
	local result = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	assert.are.same(expected, result)
	vim.api.nvim_buf_delete(bufnr, { force = true })
end

describe("ANSI escape sequence handling", function()
	describe("filter mode", function()
		before_each(function()
			helpers.setup_tests({
				ansi_color_for_compilation = "filter",
			})
		end)

		it("strips CSI non-SGR sequences", function()
			assert_output([[printf 'hello\e[1Aworld\n']], { "helloworld" })
		end)

		it("strips SGR sequences", function()
			assert_output([[printf 'hello\e[31mworld\n']], { "helloworld" })
		end)

		it("strips OSC sequences with BEL terminator", function()
			assert_output([[printf 'hello\e]2;mytitle\aworld\n']], { "helloworld" })
		end)

		it("strips OSC sequences with ST terminator", function()
			assert_output([[printf 'hello\e]2;mytitle\e\\world\n']], { "helloworld" })
		end)

		it("strips mixed CSI + OSC + SGR sequences", function()
			assert_output([[printf '\e[31m\e]2;title\ahello\e[1Aworld\n']], { "helloworld" })
		end)

		it("passes plain text through unchanged", function()
			assert_output("echo 'hello world'", { "hello world" })
		end)

		it("strips multiple CSI sequences on one line", function()
			assert_output([[printf '\e[1A\e[K\e[31mhello\e[0m\n']], { "hello" })
		end)

		it("strips line that is only escape sequences", function()
			assert_output([[printf '\e[31m\e[0m\n']], { "" })
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
		assert_output([[printf 'hello\e[1Aworld\n']], { "hello\27[1Aworld" })
	end)

	it("leaves OSC sequences in buffer as-is", function()
		assert_output([[printf 'hello\e]2;title\aworld\n']], { "hello\27]2;title\7world" })
	end)

	it("leaves SGR sequences in buffer as-is", function()
		assert_output([[printf '\e[31mhello\e[0m\n']], { "\27[31mhello\27[0m" })
	end)
end)

describe("partial sequence buffering", function()
	local ansi

	before_each(function()
		helpers.setup_tests({ ansi_color_for_compilation = "filter" })
		ansi = require("compile-mode.ansi")
	end)
	it("buffers incomplete CSI at end of chunk", function()
		assert_buffer({ { "hello\27[" }, { "1Aworld" } }, { "hello", "world" })
	end)

	it("buffers incomplete OSC at end of chunk", function()
		assert_buffer({ { "hello\27]2;tit" }, { "le\7world" } }, { "hello", "world" })
	end)

	it("buffers lone ESC at end of chunk", function()
		assert_buffer({ { "hello\27" }, { "[1Aworld" } }, { "hello", "world" })
	end)

	it("reassembles multiple chunks correctly", function()
		assert_buffer({ { "line1" }, { "line\27[31m2" }, { "\27[0m" } }, { "line1", "line2", "" })
	end)

	it("reassembles across 3 chunks", function()
		assert_buffer({ { "hello\27" }, { "[" }, { "1Aworld" } }, { "hello", "", "world" })
	end)

	it("handles complete sequence followed by partial at end", function()
		assert_buffer(
			{ { "hello\27[1A\27[" }, { "31m" }, { "world" } },
			{ "hello", "", "world" }
		)
	end)

	it("buffers incomplete OSC at end of chunk with ST terminator", function()
		assert_buffer({ { "hello\27]2;tit" }, { "le\27\\world" } }, { "hello", "world" })
	end)

	it("handles entire line being a partial sequence", function()
		assert_buffer({ { "\27[" }, { "1Ahello" } }, { "", "hello" })
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

		assert_output(
			[[printf '\e]2;mytitle\a\e]7;file:///tmp\a\e]0;iconname\ahello\n']],
			{ "hello" }
		)
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

		assert_output([[printf '\e]2;my window title\ahello\n']], { "hello" })
		assert.are.same("my window title", received_data)
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

		assert_output([[printf '\e]7;file:///home/user\ahello\n']], { "hello" })
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

		assert_output([[printf '\e]99;customdata\ahello\n']], { "hello" })
		assert.is_true(handler_called)
	end)

	it("OSC 8 hyperlink with params renders URI visible", function()
		helpers.setup_tests({
			ansi_color_for_compilation = "filter",
		})

		assert_output(
			[[printf '\e]8;id=123;https://example.com\e\\click here\e]8;;\e\\\n']],
			{ "https://example.com click here" }
		)
	end)

	it("OSC 8 hyperlink with empty params renders URI visible", function()
		helpers.setup_tests({
			ansi_color_for_compilation = "filter",
		})

		assert_output(
			[[printf '\e]8;;https://example.com\e\\click here\e]8;;\e\\\n']],
			{ "https://example.com click here" }
		)
	end)

	it("OSC 8 hyperlink with URI containing semicolons renders full URI", function()
		helpers.setup_tests({
			ansi_color_for_compilation = "filter",
		})

		assert_output(
			[[printf '\e]8;;https://example.com/path?a=1;b=2\e\\link\e]8;;\e\\\n']],
			{ "https://example.com/path?a=1;b=2 link" }
		)
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

		assert_output([[printf 'hello\e]2;mytitle\aworld\n']], { "hello[TITLE]world" })
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

		assert_output([[printf 'hello\e]2;mytitle\aworld\n']], { "helloworld" })
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

		assert_output([[printf '\e]2;title\ahello\n']], { "hello" })
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

describe("pattern correctness", function()
	local ansi

	before_each(function()
		helpers.setup_tests({ ansi_color_for_compilation = "filter" })
		ansi = require("compile-mode.ansi")
	end)

	it("non-SGR pattern preserves SGR sequences (final byte m)", function()
		local result = ansi._strip_non_sgr_csi("\27[32mGREEN\27[0m")
		assert.are.equal("\27[32mGREEN\27[0m", result)
	end)

	it("non-SGR pattern strips cursor up (final byte A)", function()
		local result = ansi._strip_non_sgr_csi("hello\27[1Aworld")
		assert.are.equal("helloworld", result)
	end)

	it("non-SGR pattern strips erase line (final byte K)", function()
		local result = ansi._strip_non_sgr_csi("hello\27[Kworld")
		assert.are.equal("helloworld", result)
	end)

	it("complete pattern strips SGR sequences", function()
		local result = ansi._strip_csi("\27[32mGREEN\27[0m")
		assert.are.equal("GREEN", result)
	end)

	it("non-SGR pattern keeps SGR but strips non-SGR", function()
		local result = ansi._strip_non_sgr_csi("\27[1A\27[K\27[32mhello\27[0m\27[1B")
		assert.are.equal("\27[32mhello\27[0m", result)
	end)

	it("non-SGR pattern preserves 256-color SGR (38;5;n)", function()
		local result = ansi._strip_non_sgr_csi("\27[38;5;214morange\27[0m")
		assert.are.equal("\27[38;5;214morange\27[0m", result)
	end)

	it("non-SGR pattern preserves RGB SGR (38;2;r;g;b)", function()
		local result = ansi._strip_non_sgr_csi("\27[38;2;255;165;0morange\27[0m")
		assert.are.equal("\27[38;2;255;165;0morange\27[0m", result)
	end)

	it("complete pattern strips all CSI including SGR", function()
		local result = ansi._strip_csi("\27[1A\27[K\27[32mhello\27[0m\27[1B")
		assert.are.equal("hello", result)
	end)

	it("OSC pattern strips BEL-terminated sequences", function()
		local result = ansi._strip_osc("hello\27]2;title\7world")
		assert.are.equal("helloworld", result)
	end)

	it("OSC pattern strips ST-terminated sequences", function()
		local result = ansi._strip_osc("hello\27]2;title\27\\world")
		assert.are.equal("helloworld", result)
	end)
end)

describe("render mode with mock baleia", function()
	local captured_lines

	local function assert_render(input, expected)
		helpers.setup_tests({ ansi_color_for_compilation = "render" })
		local ansi = require("compile-mode.ansi")
		local bufnr = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "" })

		ansi.buf_set_lines(bufnr, 0, -1, { input })

		assert.are.same(expected, captured_lines)
		vim.api.nvim_buf_delete(bufnr, { force = true })
	end

	before_each(function()
		captured_lines = {}
		package.loaded["baleia"] = {
			setup = function(opts)
				return {
					buf_set_lines = function(bufnr, start, end_, strict, lines)
						for _, l in ipairs(lines) do
							table.insert(captured_lines, l)
						end
					end,
				}
			end,
		}
	end)

	after_each(function()
		package.loaded["baleia"] = nil
	end)

	it("passes SGR sequences through to baleia", function()
		assert_render("\27[32mGREEN\27[0m", { "\27[32mGREEN\27[0m" })
	end)

	it("strips non-SGR CSI before passing to baleia", function()
		assert_render("\27[1A\27[32mGREEN\27[0m", { "\27[32mGREEN\27[0m" })
	end)

	it("strips OSC before passing to baleia", function()
		assert_render("\27]2;title\7\27[32mGREEN\27[0m", { "\27[32mGREEN\27[0m" })
	end)
end)
