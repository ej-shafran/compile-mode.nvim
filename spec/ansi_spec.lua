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
				ansi_color = { kind = "filter" },
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

		it("strips cmake-style color codes, keeps visible text", function()
			assert_output([[printf '[ \e[1;32mOK\e[0;39m ] [ \e[1;31mFAIL\e[0;39m ]\n']], { "[ OK ] [ FAIL ]" })
		end)
	end)
end)

describe("passthrough mode", function()
	before_each(function()
		helpers.setup_tests({
			ansi_color = { kind = "passthrough" },
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
		helpers.setup_tests({ ansi_color = { kind = "filter" } })
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
		assert_buffer({ { "hello\27[1A\27[" }, { "31m" }, { "world" } }, { "hello", "", "world" })
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
	it("default handlers strip sequences from output", function()
		helpers.setup_tests({
			ansi_color = { kind = "filter" },
		})

		assert_output([[printf '\e]2;mytitle\a\e]7;file:///tmp\a\e]0;iconname\ahello\n']], { "hello" })
	end)

	it("custom handler for command 2 receives title data", function()
		local received_data = nil

		helpers.setup_tests({
			ansi_color = { kind = "filter" },
			ansi_osc = {
				kind = "filter",
				handlers = {
					[2] = function(ctx)
						received_data = ctx.data
						return ""
					end,
				},
			},
		})

		assert_output([[printf '\e]2;my window title\ahello\n']], { "hello" })
		assert.are.same("my window title", received_data)
	end)

	it("custom handler for command 7 receives cwd data", function()
		local received_data = nil

		helpers.setup_tests({
			ansi_color = { kind = "filter" },
			ansi_osc = {
				kind = "filter",
				handlers = {
					[7] = function(ctx)
						received_data = ctx.data
						return ""
					end,
				},
			},
		})

		assert_output([[printf '\e]7;file:///home/user\ahello\n']], { "hello" })
		assert.are.same("file:///home/user", received_data)
	end)

	it("custom handler for unknown OSC command 99 is called", function()
		local handler_called = false

		helpers.setup_tests({
			ansi_color = { kind = "filter" },
			ansi_osc = {
				kind = "filter",
				handlers = {
					[99] = function(_)
						handler_called = true
						return ""
					end,
				},
			},
		})

		assert_output([[printf '\e]99;customdata\ahello\n']], { "hello" })
		assert.is_true(handler_called)
	end)

	it("OSC 8 hyperlink with params strips escape from output", function()
		helpers.setup_tests({
			ansi_color = { kind = "filter" },
			ansi_osc = { kind = "render" },
		})

		assert_output([[printf '\e]8;id=123;https://example.com\e\\click here\e]8;;\e\\\n']], { "click here" })
	end)

	it("OSC 8 hyperlink with empty params strips escape from output", function()
		helpers.setup_tests({
			ansi_color = { kind = "filter" },
			ansi_osc = { kind = "render" },
		})

		assert_output([[printf '\e]8;;https://example.com\e\\click here\e]8;;\e\\\n']], { "click here" })
	end)

	it("OSC 8 hyperlink with URI containing semicolons strips escape from output", function()
		helpers.setup_tests({
			ansi_color = { kind = "filter" },
			ansi_osc = { kind = "render" },
		})

		assert_output([[printf '\e]8;;https://example.com/path?a=1;b=2\e\\link\e]8;;\e\\\n']], { "link" })
	end)

	it("handler return value replaces the OSC sequence in buffer", function()
		helpers.setup_tests({
			ansi_color = { kind = "filter" },
			ansi_osc = { kind = "filter", handlers = {
				[2] = function(_)
					return "[TITLE]"
				end,
			} },
		})

		assert_output([[printf 'hello\e]2;mytitle\aworld\n']], { "hello[TITLE]world" })
	end)

	it("handler returning empty string strips the sequence entirely", function()
		helpers.setup_tests({
			ansi_color = { kind = "filter" },
			ansi_osc = { kind = "filter", handlers = {
				[2] = function(_)
					return ""
				end,
			} },
		})

		assert_output([[printf 'hello\e]2;mytitle\aworld\n']], { "helloworld" })
	end)

	it("handlers fire in filter mode", function()
		local fired = false

		helpers.setup_tests({
			ansi_color = { kind = "filter" },
			ansi_osc = {
				kind = "filter",
				handlers = {
					[2] = function(_)
						fired = true
						return ""
					end,
				},
			},
		})

		assert_output([[printf '\e]2;title\ahello\n']], { "hello" })
		assert.is_true(fired)
	end)

	it("OSC 2 sets titlestring in render mode", function()
		helpers.setup_tests({
			ansi_color = { kind = "filter" },
			ansi_osc = { kind = "render" },
		})

		assert_output([[printf '\e]2;My Title\ahello\n']], { "hello" })
		assert.are.same("My Title", vim.opt.titlestring:get())
	end)

	it("OSC 0 sets titlestring and iconstring in render mode", function()
		helpers.setup_tests({
			ansi_color = { kind = "filter" },
			ansi_osc = { kind = "render" },
		})

		assert_output([[printf '\e]0;My Icon Title\ahello\n']], { "hello" })
		assert.are.same("My Icon Title", vim.opt.titlestring:get())
		assert.are.same("My Icon Title", vim.opt.iconstring:get())
	end)

	it("OSC 1 sets iconstring in render mode", function()
		helpers.setup_tests({
			ansi_color = { kind = "filter" },
			ansi_osc = { kind = "render" },
		})

		assert_output([[printf '\e]1;My Icon\ahello\n']], { "hello" })
		assert.are.same("My Icon", vim.opt.iconstring:get())
	end)

	it("OSC 9 fires vim.notify in render mode", function()
		local captured = {}
		local orig = vim.notify
		---@diagnostic disable-next-line: duplicate-set-field
		vim.notify = function(msg, level)
			captured.msg = msg
			captured.level = level
		end

		helpers.setup_tests({
			ansi_color = { kind = "filter" },
			ansi_osc = { kind = "render" },
		})

		assert_output([[printf '\e]9;Build complete\ahello\n']], { "hello" })

		assert.equals("Build complete", captured.msg)
		assert.equals(vim.log.levels.INFO, captured.level)

		vim.notify = orig
	end)

	it("ansi_osc passthrough leaves OSC sequences intact", function()
		helpers.setup_tests({
			ansi_color = { kind = "filter" },
			ansi_osc = { kind = "passthrough" },
		})

		assert_output([[printf 'hello\e]2;title\aworld\n']], { "hello\27]2;title\7world" })
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
			ansi_color = { kind = "render" },
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
		helpers.setup_tests({ ansi_color = { kind = "filter" } })
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
		helpers.setup_tests({ ansi_color = { kind = "filter" } })
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
		helpers.setup_tests({ ansi_color = { kind = "render" } })
		local ansi = require("compile-mode.ansi")
		local bufnr = vim.api.nvim_create_buf(false, true)

		ansi.buf_set_lines(bufnr, 0, -1, { input })

		assert.are.same(expected, captured_lines)
		vim.api.nvim_buf_delete(bufnr, { force = true })
	end

	before_each(function()
		captured_lines = {}
		local ansi_mod = require("compile-mode.ansi")
		package.loaded["baleia"] = {
			setup = function(opts)
				return {
					buf_set_lines = function(bufnr, start, end_, strict, lines)
						for _, l in ipairs(lines) do
							table.insert(captured_lines, l)
						end
						local cleaned = vim.tbl_map(function(l)
							return ansi_mod._strip_sgr(l)
						end, lines)
						vim.api.nvim_buf_set_lines(bufnr, start, end_, strict, cleaned)
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

describe("OSC 8 hyperlink extmarks", function()
	local ansi
	local ns_id

	before_each(function()
		helpers.setup_tests({ ansi_color = { kind = "filter" }, ansi_osc = { kind = "render" } })
		ansi = require("compile-mode.ansi")
		ns_id = ansi.ns_id
	end)

	it("places extmark with URL on linked text", function()
		local bufnr = vim.api.nvim_create_buf(false, true)

		ansi.buf_set_lines(bufnr, 0, -1, { "\27]8;;https://example.com\27\\click here\27]8;;\27\\" })

		local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
		assert.are.same({ "click here" }, lines)

		local extmarks = vim.api.nvim_buf_get_extmarks(bufnr, ns_id, 0, -1, { details = true })
		assert.equals(1, #extmarks)

		local mark = extmarks[1]
		assert.equals("https://example.com", mark[4].url)
		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	it("places extmark across multiple linked regions", function()
		local bufnr = vim.api.nvim_create_buf(false, true)

		ansi.buf_set_lines(bufnr, 0, -1, {
			"\27]8;;https://a.com\27\\link a\27]8;;\27\\plain \27]8;;https://b.com\27\\link b\27]8;;\27\\",
		})

		local extmarks = vim.api.nvim_buf_get_extmarks(bufnr, ns_id, 0, -1, { details = true })
		assert.equals(2, #extmarks)

		local urls = vim.tbl_map(function(m)
			return m[4].url
		end, extmarks)
		assert.are.same({ "https://a.com", "https://b.com" }, urls)

		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	it("handles link across multiple lines in one chunk", function()
		local bufnr = vim.api.nvim_create_buf(false, true)

		ansi.buf_set_lines(bufnr, 0, -1, {
			"before",
			"mid\27]8;;https://multi.com\27\\start",
			"end\27]8;;\27\\after",
		})

		local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
		assert.are.same({ "before", "midstart", "endafter" }, lines)

		local extmarks = vim.api.nvim_buf_get_extmarks(bufnr, ns_id, 0, -1, { details = true })
		assert.equals(1, #extmarks)

		local m = extmarks[1]
		assert.equals("https://multi.com", m[4].url)

		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	it("handles link close without prior open gracefully", function()
		local bufnr = vim.api.nvim_create_buf(false, true)

		ansi.buf_set_lines(bufnr, 0, -1, { "before\27]8;;\27\\after" })

		local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
		assert.are.same({ "beforeafter" }, lines)

		local extmarks = vim.api.nvim_buf_get_extmarks(bufnr, ns_id, 0, -1, { details = true })
		assert.equals(0, #extmarks)

		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	it("second link open replaces first link gracefully", function()
		local bufnr = vim.api.nvim_create_buf(false, true)

		ansi.buf_set_lines(bufnr, 0, -1, {
			"\27]8;;https://first.com\27\\first\27]8;;https://second.com\27\\second\27]8;;\27\\",
		})

		local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
		assert.are.same({ "firstsecond" }, lines)

		-- Only the second link should have an extmark
		local extmarks = vim.api.nvim_buf_get_extmarks(bufnr, ns_id, 0, -1, { details = true })
		assert.equals(1, #extmarks)
		assert.equals("https://second.com", extmarks[1][4].url)

		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	it("places extmarks with negative start in filter mode", function()
		local bufnr = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "make -k ", "" })

		ansi.buf_set_lines(bufnr, -2, -1, { "\27]8;;https://example.com\27\\click here\27]8;;\27\\" })

		local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
		assert.are.same({ "make -k ", "click here" }, lines)

		local extmarks = vim.api.nvim_buf_get_extmarks(bufnr, ns_id, 0, -1, { details = true })
		assert.equals(1, #extmarks)
		assert.equals("https://example.com", extmarks[1][4].url)
		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	it("places extmark at correct column with SGR in render mode", function()
		helpers.setup_tests({ ansi_color = { kind = "render" }, ansi_osc = { kind = "render" } })
		local ansi = require("compile-mode.ansi")
		package.loaded["baleia"] = {
			setup = function()
				return {
					buf_set_lines = function(bufnr, start, end_, strict, lines)
						local cleaned = vim.tbl_map(function(l)
							return ansi._strip_sgr(l)
						end, lines)
						vim.api.nvim_buf_set_lines(bufnr, start, end_, strict, cleaned)
					end,
				}
			end,
		}
		package.loaded["compile-mode.ansi"] = nil
		ansi = require("compile-mode.ansi")
		local bufnr = vim.api.nvim_create_buf(false, true)

		ansi.buf_set_lines(bufnr, 0, -1, { "\27[32mGREEN \27]8;;https://example.com\27\\link\27]8;;\27\\" })

		local extmarks = vim.api.nvim_buf_get_extmarks(bufnr, ansi.ns_id, 0, -1, { details = true })
		assert.equals(1, #extmarks)

		local m = extmarks[1]
		assert.equals(6, m[3])
		assert.equals(10, m[4].end_col)
		vim.api.nvim_buf_delete(bufnr, { force = true })
		package.loaded["baleia"] = nil
	end)

	it("places extmark at correct column with SGR in filter mode", function()
		local bufnr = vim.api.nvim_create_buf(false, true)

		ansi.buf_set_lines(bufnr, 0, -1, { "\27[32mGREEN \27]8;;https://example.com\27\\link\27]8;;\27\\" })

		local extmarks = vim.api.nvim_buf_get_extmarks(bufnr, ns_id, 0, -1, { details = true })
		assert.equals(1, #extmarks)

		local m = extmarks[1]
		assert.equals(6, m[3])
		assert.equals(10, m[4].end_col)
		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)
end)

describe("ansi_color config validation", function()
	local check

	before_each(function()
		helpers.setup_tests({})
		package.loaded["compile-mode.config.check"] = nil
		check = require("compile-mode.config.check")
	end)

	local function validate(ac_override)
		local cfg = helpers.get_default_config()
		cfg.ansi_color = ac_override
		return check.validate(cfg)
	end

	it("accepts valid kind: filter", function()
		assert.is_true(validate({ kind = "filter" }))
	end)

	it("accepts valid kind: render", function()
		assert.is_true(validate({ kind = "render" }))
	end)

	it("accepts valid kind: passthrough", function()
		assert.is_true(validate({ kind = "passthrough" }))
	end)

	it("accepts baleia_setup as true", function()
		assert.is_true(validate({ kind = "render", baleia_setup = true }))
	end)

	it("accepts baleia_setup as table", function()
		assert.is_true(validate({ kind = "render", baleia_setup = { colors = {} } }))
	end)

	it("accepts baleia_setup as false", function()
		assert.is_true(validate({ kind = "filter", baleia_setup = false }))
	end)

	it("rejects flat string value", function()
		local cfg = helpers.get_default_config()
		cfg.ansi_color = "filter"
		assert.is_false(check.validate(cfg))
	end)

	it("rejects table with invalid kind", function()
		assert.is_false(validate({ kind = "invalid" }))
	end)

	it("rejects table with missing kind", function()
		assert.is_false(validate({}))
	end)

	it("rejects wrong type for ansi_color", function()
		local cfg = helpers.get_default_config()
		cfg.ansi_color = 123
		assert.is_false(check.validate(cfg))
	end)

	it("rejects nil kind", function()
		assert.is_false(validate({ kind = nil }))
	end)
end)

describe("baleia_setup deprecation", function()
	local function resolved_config()
		package.loaded["compile-mode.config.internal"] = nil
		return require("compile-mode.config.internal")
	end

	it("migrates top-level baleia_setup = true to render", function()
		helpers.setup_tests({ baleia_setup = true })
		local cfg = resolved_config()
		assert.are.same({ kind = "render", baleia_setup = true }, cfg.ansi_color)
	end)

	it("migrates top-level baleia_setup = table to render", function()
		helpers.setup_tests({ baleia_setup = { colors = {} } })
		local cfg = resolved_config()
		assert.are.same({ kind = "render", baleia_setup = { colors = {} } }, cfg.ansi_color)
	end)

	it("does not migrate baleia_setup = false", function()
		helpers.setup_tests({ baleia_setup = false })
		local cfg = resolved_config()
		assert.are.same({ kind = "filter", baleia_setup = false }, cfg.ansi_color)
	end)

	it("keeps default ansi_color when baleia_setup is not set", function()
		helpers.setup_tests({})
		local cfg = resolved_config()
		assert.are.same({ kind = "filter", baleia_setup = false }, cfg.ansi_color)
	end)

	it("top-level baleia_setup overrides explicit ansi_color config", function()
		helpers.setup_tests({
			ansi_color = { kind = "filter", baleia_setup = false },
			baleia_setup = { colors = {} },
		})
		local cfg = resolved_config()
		assert.are.same({ kind = "render", baleia_setup = { colors = {} } }, cfg.ansi_color)
	end)
end)

describe("ansi_osc config validation", function()
	local check

	before_each(function()
		helpers.setup_tests({})
		package.loaded["compile-mode.config.check"] = nil
		check = require("compile-mode.config.check")
	end)

	local function validate(osc_override)
		local cfg = helpers.get_default_config()
		cfg.ansi_osc = osc_override
		return check.validate(cfg)
	end

	it("accepts valid kind: filter", function()
		assert.is_true(validate({ kind = "filter" }))
	end)

	it("accepts valid kind: render", function()
		assert.is_true(validate({ kind = "render" }))
	end)

	it("accepts valid kind: passthrough", function()
		assert.is_true(validate({ kind = "passthrough" }))
	end)

	it("accepts handlers alongside kind", function()
		assert.is_true(validate({ kind = "filter", handlers = {
			[2] = function(_)
				return ""
			end,
		} }))
	end)

	it("rejects flat string value", function()
		local cfg = helpers.get_default_config()
		cfg.ansi_osc = "filter"
		assert.is_false(check.validate(cfg))
	end)

	it("rejects table with invalid kind", function()
		assert.is_false(validate({ kind = "invalid" }))
	end)

	it("rejects table with missing kind", function()
		assert.is_false(validate({}))
	end)

	it("rejects wrong type for ansi_osc", function()
		local cfg = helpers.get_default_config()
		cfg.ansi_osc = 123
		assert.is_false(check.validate(cfg))
	end)

	it("rejects nil kind", function()
		assert.is_false(validate({ kind = nil }))
	end)
end)

-- Run these commands inside Neovim to test interactively:
-- SGR colors: OK=green, FAIL=red
-- Compile printf '\\033[1;32mOK\\033[0m \\033[1;31mFAIL\\033[0m'
-- OSC 8: clickable hyperlink
-- Compile printf '\\033]8;;https://example.com\\033\\\\click here\\033]8;;\\033\\\\'
-- OSC 0: sets titlestring + iconstring
-- Compile printf '\\033]0;My Window Title\\033\\\\'
--   Check: :echo &titlestring → "My Window Title", :echo &iconstring → "My Window Title"
-- OSC 1: sets iconstring
-- Compile printf '\\033]1;My Icon\\033\\\\'
--   Check: :echo &iconstring → "My Icon"
-- OSC 2: sets titlestring
-- Compile printf '\\033]2;My Title\\033\\\\'
--   Check: :echo &titlestring → "My Title"
-- OSC 9: fires vim.notify
-- Compile printf '\\033]9;Build done\\033\\\\'
--   Check: :messages → "Build done"
