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
local mode = "render"
local osc_handlers = {}
---@type table?
local baleia_instance = nil
local initialized = false

local M = {}

local function setup(config)
	mode = config.ansi_color_for_compilation
	osc_handlers = config.osc_handlers
	if mode == "render" then
		local ok, baleia_mod = pcall(require, "baleia")
		if ok then
			baleia_instance = baleia_mod.setup(config.baleia_setup == true and {} or config.baleia_setup)
		else
			log.warn(
				"ansi_color_for_compilation is 'render' but baleia.nvim could not be loaded. "
					.. "Falling back to 'filter'."
			)
			mode = "filter"
		end
	end
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

local function process_osc(line)
	line = line:gsub(OSC_BEL_PATTERN, function(cmd, data)
		local handler = osc_handlers[tonumber(cmd)]
		if handler then
			return handler(data)
		end
		return ""
	end)
	line = line:gsub(OSC_ST_PATTERN, function(cmd, data)
		local handler = osc_handlers[tonumber(cmd)]
		if handler then
			return handler(data)
		end
		return ""
	end)
	return line
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

---Strip non-SGR CSI and OSC, let baleia handle SGR (strip + color extmarks).
---@param bufnr integer
---@param start integer
---@param end_ integer
---@param lines string[]
local function render(bufnr, start, end_, lines)
	handle_partial(lines)
	for i, line in ipairs(lines) do
		lines[i] = process_osc(strip_non_sgr_csi(line))
	end
	-- Baleia's buf_set_lines uses start as absolute row for extmarks.
	-- Negative indices (like -2) are invalid for nvim_buf_set_extmark.
	if start < 0 then
		start = vim.api.nvim_buf_line_count(bufnr) + start + 1
	end
	if end_ < 0 then
		end_ = vim.api.nvim_buf_line_count(bufnr) + end_ + 1
	end
	---@cast baleia_instance table
	baleia_instance.buf_set_lines(bufnr, start, end_, false, lines)
end

---Strip all CSI and OSC sequences, write plain text.
---@param bufnr integer
---@param start integer
---@param end_ integer
---@param lines string[]
local function filter(bufnr, start, end_, lines)
	handle_partial(lines)
	for i, line in ipairs(lines) do
		lines[i] = process_osc(strip_csi(line))
	end
	vim.api.nvim_buf_set_lines(bufnr, start, end_, false, lines)
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
	if mode == "filter" then
		line = process_osc(strip_csi(line))
	elseif mode == "render" then
		line = process_osc(strip_non_sgr_csi(line))
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

return M
