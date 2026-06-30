local log = require("compile-mode.log")

-- Lua pattern building blocks for ANSI escape sequence processing.
-- All patterns are sourced from Emacs' ansi-color.el and ansi-osc.el.
-- See:
-- - https://github.com/emacs-mirror/emacs/blob/master/lisp/ansi-color.el
-- - https://github.com/emacs-mirror/emacs/blob/master/lisp/ansi-osc.el

local ESC = "\x1b" -- ESC byte (0x1B)

-- CSI (Control Sequence Introducer) structure:
--   ESC [ <parameter bytes> <intermediate bytes> <final byte>
-- Parameter bytes: 0x30-0x3F (0-9 : ; < = > ?)
-- Intermediate bytes: 0x20-0x2F (space through /)
-- Final bytes: 0x40-0x7E (@ through ~)

local CSI_INTRO = ESC .. "%["
local CSI_PARAM = "[%d:;<=>?]*"
local CSI_INTERMEDIATE = "[ -/]*"
local CSI_FINAL = "[@-~]"
local CSI_FINAL_NON_SGR = "[@-ln-~]" -- excludes m (0x6D, SGR final byte)

-- Composed CSI patterns
local CSI_COMPLETE = CSI_INTRO .. CSI_PARAM .. CSI_INTERMEDIATE .. CSI_FINAL
local CSI_NON_SGR = CSI_INTRO .. CSI_PARAM .. CSI_INTERMEDIATE .. CSI_FINAL_NON_SGR
local CSI_SGR = CSI_INTRO .. CSI_PARAM .. CSI_INTERMEDIATE .. "m"

-- Partial CSI patterns (incomplete sequences at end of input)
local PARTIAL_CSI = CSI_INTRO .. CSI_PARAM .. CSI_INTERMEDIATE .. "$"
local LONE_ESC = ESC .. "$"

-- OSC (Operating System Command) structure:
--   ESC ] <command> ; <data> <terminator>
-- Terminators: BEL (0x07) or ESC \ (ST)

local OSC_INTRO = ESC .. "%]"
local OSC_CMD = "(%d+)" -- captures command number
local OSC_SEP = ";"
local OSC_DATA = "([^\x07\x1b]-)" -- captures data (non-greedy, stops at BEL or ESC)
local BEL = "\x07" -- BEL byte (0x07)
local ST = ESC .. "\\" -- String Terminator: ESC \
local OSC_TEXT = "[^\x07\x1b]*" -- for BEL-terminated and partial patterns
local OSC_TEXT_ST = "[^\x1b]*" -- for ST-terminated (BEL is allowed in data)

-- Composed OSC patterns with captures (for handler dispatch)
local OSC_BEL_PATTERN = OSC_INTRO .. OSC_CMD .. OSC_SEP .. OSC_DATA .. BEL
local OSC_ST_PATTERN = OSC_INTRO .. OSC_CMD .. OSC_SEP .. OSC_DATA .. ST

-- Composed OSC patterns without captures (for stripping)
local OSC_BEL_TERM = OSC_INTRO .. OSC_TEXT .. BEL
local OSC_ST_TERM = OSC_INTRO .. OSC_TEXT_ST .. ST

-- Partial OSC pattern (incomplete sequence at end of input)
local PARTIAL_OSC = OSC_INTRO .. OSC_TEXT .. "$"

local partial_buffer = ""
local mode = "filter"
local osc_kind = "render"
local osc_handlers = {}
---@type table?
local baleia_instance = nil
local initialized = false

local M = {}

M.ns_id = vim.api.nvim_create_namespace("compile-mode-ansi-osc")
vim.api.nvim_set_hl(0, "CompileModeUrl", { underline = true, sp = "#569cd6" })

---@param config CompileModeConfig
local function setup(config)
	local ansi_cfg = config.ansi_color
	mode = ansi_cfg.kind
	if mode == "render" then
		local baleia_setup = ansi_cfg.baleia_setup
		if baleia_setup == nil or baleia_setup == false then
			baleia_setup = true
		end
		local ok, baleia_mod = pcall(require, "baleia")
		if ok then
			baleia_instance = baleia_mod.setup(baleia_setup == true and {} or baleia_setup)
		else
			log.warn("ansi_color.kind is 'render' but baleia.nvim could not be loaded. Falling back to 'filter'.")
			mode = "filter"
		end
	end

	local osc_cfg = config.ansi_osc
	osc_kind = osc_cfg.kind
	local defaults = {}
	if osc_kind == "render" then
		defaults = {
			[0] = function(ctx)
				vim.opt.titlestring = ctx.data
				vim.opt.iconstring = ctx.data
				return ""
			end,
			[1] = function(ctx)
				vim.opt.iconstring = ctx.data
				return ""
			end,
			[2] = function(ctx)
				vim.opt.titlestring = ctx.data
				return ""
			end,
			[9] = function(ctx)
				vim.notify(ctx.data, vim.log.levels.INFO)
				return ""
			end,
			[8] = function(ctx)
				local uri = ctx.data:match(";%s*(.*)")
				if uri and uri ~= "" then
					return "", { link_open = { uri = uri } }
				end
				return "", { link_close = true }
			end,
		}
	end
	osc_handlers = vim.tbl_extend("keep", osc_cfg.handlers or {}, defaults)
end

---Strip all CSI sequences (SGR and non-SGR) from a line.
---@param line string
---@return string
local function strip_csi(line)
	return (line:gsub(CSI_COMPLETE, ""))
end

---Strip non-SGR CSI sequences from a line, keeping SGR (color) sequences intact.
---@param line string
---@return string
local function strip_non_sgr_csi(line)
	return (line:gsub(CSI_NON_SGR, ""))
end

---Strip all OSC sequences from a line.
---@param line string
---@return string
local function strip_osc(line)
	return (line:gsub(OSC_BEL_TERM, ""):gsub(OSC_ST_TERM, ""))
end

---@class AnsiOscLinkState
---@field open { uri: string, row: integer, col: integer }?
---@field pending AnsiOscExtmark[]

local function visible_len(pieces)
	local text = table.concat(pieces)
	local len = #text:gsub(CSI_SGR, "")
	return len
end

---Walk through line manually tracking positions, process OSC sequences.
---Returns cleaned line. Side-effects: modifies link_state for extmark placement.
---@param line string
---@param bufnr integer
---@param row integer 0-indexed absolute row in buffer
---@param link_state AnsiOscLinkState
---@return string
local function process_osc(line, bufnr, row, link_state)
	local pieces = {}
	local pos = 1

	while pos <= #line do
		local osc_start = string.find(line, OSC_INTRO, pos)
		if not osc_start then
			break
		end

		local before = line:sub(pos, osc_start - 1)
		table.insert(pieces, before)

		-- Find terminator: BEL (\x07) or ST (ESC \)
		local bel = string.find(line, BEL, osc_start)
		local st = string.find(line, ST, osc_start)
		local body, body_end

		if bel and (not st or bel < st) then
			body = line:sub(osc_start + 2, bel - 1)
			body_end = bel
		elseif st then
			body = line:sub(osc_start + 2, st - 1)
			body_end = st + 1
		else
			-- Incomplete sequence, keep remaining text as-is
			table.insert(pieces, line:sub(osc_start))
			pos = #line + 1
			break
		end

		local semicolon = string.find(body, ";")
		if semicolon then
			local cmd = tonumber(body:sub(1, semicolon - 1))
			local data = body:sub(semicolon + 1)
			local handler = cmd and osc_handlers[cmd]
			if handler then
				local text, meta = handler({ bufnr = bufnr, data = data })
				if meta then
					if meta.link_open then
						link_state.open = {
							uri = meta.link_open.uri,
							row = row,
							col = visible_len(pieces),
						}
					elseif meta.link_close and link_state.open then
						table.insert(link_state.pending, {
							start_row = link_state.open.row,
							start_col = link_state.open.col,
							end_row = row,
							end_col = visible_len(pieces),
							url = link_state.open.uri,
						})
						link_state.open = nil
					end
				end
				if text and text ~= "" then
					table.insert(pieces, text)
				end
			end
		end

		pos = body_end + 1
	end

	table.insert(pieces, line:sub(pos))
	return table.concat(pieces)
end

---Check if a line ends with a partial escape sequence.
---@param line string
---@return integer|nil start_pos 1-indexed byte position where partial begins, or nil
local function check_partial(line)
	local csi = string.find(line, PARTIAL_CSI)
	if not csi then
		csi = string.find(line, LONE_ESC)
	end
	local osc = string.find(line, PARTIAL_OSC)
	if csi and osc then
		return math.min(csi, osc)
	elseif csi then
		return csi
	elseif osc then
		return osc
	end
	return nil
end

---Prepend pending partial and check for new partial at end.
---@param lines string[]
local function handle_partial(lines)
	lines[1] = partial_buffer .. lines[1]
	partial_buffer = ""

	local last = lines[#lines]
	local partial_start = check_partial(last)
	if partial_start then
		partial_buffer = last:sub(partial_start)
		lines[#lines] = last:sub(1, partial_start - 1)
	end
end

---@alias AnsiOscExtmark { start_row: integer, start_col: integer, end_row: integer, end_col: integer, url: string }

---Place pending URL extmarks from link tracking.
---@param bufnr integer
---@param pending AnsiOscExtmark[]
local function apply_osc_extmarks(bufnr, pending)
	for _, em in ipairs(pending) do
		local ok, err = pcall(vim.api.nvim_buf_set_extmark, bufnr, M.ns_id, em.start_row, em.start_col, {
			end_row = em.end_row,
			end_col = em.end_col,
			url = em.url,
			hl_group = "CompileModeUrl",
		})
		if not ok then
			log.fmt_warn("failed to place URL extmark: %s", err)
		end
	end
end

---Strip non-SGR CSI and OSC, let baleia handle SGR (strip + color extmarks).
---@param bufnr integer
---@param start integer
---@param end_ integer
---@param lines string[]
local function render(bufnr, start, end_, lines)
	handle_partial(lines)
	local link_state = { open = nil, pending = {} }
	-- Baleia's buf_set_lines uses start as absolute row for extmarks.
	-- Negative indices (like -2) are invalid for nvim_buf_set_extmark.
	if start < 0 then
		start = vim.api.nvim_buf_line_count(bufnr) + start + 1
	end
	if end_ < 0 then
		end_ = vim.api.nvim_buf_line_count(bufnr) + end_ + 1
	end
	for i, line in ipairs(lines) do
		line = strip_non_sgr_csi(line)
		if osc_kind ~= "passthrough" then
			line = process_osc(line, bufnr, start + i - 1, link_state)
		end
		lines[i] = line
	end
	---@cast baleia_instance table
	baleia_instance.buf_set_lines(bufnr, start, end_, false, lines)
	apply_osc_extmarks(bufnr, link_state.pending)
end

---Strip all CSI and OSC sequences, write plain text.
---@param bufnr integer
---@param start integer
---@param end_ integer
---@param lines string[]
local function filter(bufnr, start, end_, lines)
	handle_partial(lines)
	local link_state = { open = nil, pending = {} }
	local abs_start = start
	if abs_start < 0 then
		abs_start = vim.api.nvim_buf_line_count(bufnr) + abs_start + 1
	end
	for i, line in ipairs(lines) do
		line = strip_csi(line)
		if osc_kind ~= "passthrough" then
			line = process_osc(line, bufnr, abs_start + i - 1, link_state)
		end
		lines[i] = line
	end
	vim.api.nvim_buf_set_lines(bufnr, start, end_, false, lines)
	apply_osc_extmarks(bufnr, link_state.pending)
end

---@param bufnr integer
---@param start integer
---@param end_ integer
---@param lines string[]
local function passthrough(bufnr, start, end_, lines)
	vim.api.nvim_buf_set_lines(bufnr, start, end_, false, lines)
end

---@param bufnr integer
---@param start integer
---@param end_ integer
---@param lines string[]
function M.buf_set_lines(bufnr, start, end_, lines)
	if not initialized then
		setup(require("compile-mode.config.internal"))
		initialized = true
	end
	local fn = (mode == "render" and render) or (mode == "filter" and filter) or passthrough
	vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
	fn(bufnr, start, end_, lines)
	vim.schedule(function()
		if vim.api.nvim_buf_is_valid(bufnr) then
			vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })
		end
	end)
end

function M.reset()
	initialized = false
	partial_buffer = ""
end

---Flush any remaining partial buffer to the compilation buffer.
---Call this when the process exits, before writing the footer.
---@param bufnr integer
function M.flush(bufnr)
	if partial_buffer == "" then
		return
	end
	local line = partial_buffer
	partial_buffer = ""
	local link_state = { open = nil, pending = {} }
	if mode == "filter" then
		line = strip_csi(line)
	elseif mode == "render" then
		line = strip_non_sgr_csi(line)
	end
	if osc_kind ~= "passthrough" then
		local flush_row = math.max(0, vim.api.nvim_buf_line_count(bufnr) - 1)
		line = process_osc(line, bufnr, flush_row, link_state)
		apply_osc_extmarks(bufnr, link_state.pending)
	end
	-- Append to last line, not create a new one
	local last = vim.api.nvim_buf_get_lines(bufnr, -2, -1, false)[1]
	vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
	vim.api.nvim_buf_set_lines(bufnr, -2, -1, false, { last .. line })
	vim.schedule(function()
		if vim.api.nvim_buf_is_valid(bufnr) then
			vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })
		end
	end)
end

M._strip_csi = strip_csi
M._strip_non_sgr_csi = strip_non_sgr_csi
M._strip_osc = strip_osc
M._strip_sgr = function(line)
	return (line:gsub(CSI_SGR, ""))
end

return M
