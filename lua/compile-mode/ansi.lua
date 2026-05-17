local log = require("compile-mode.log")

-- All patterns are sourced directly from Emacs' ansi-color.el and ansi-osc.el,
-- translated to Vim regex syntax. See:
-- - https://github.com/emacs-mirror/emacs/blob/ee9b2db1cf036d6f511d7e6eea0189073076e7c0/lisp/ansi-color.el
-- - https://github.com/emacs-mirror/emacs/blob/master/lisp/ansi-osc.el

-- CSI (Control Sequence Introducer) structure:
--   ESC [ <parameter bytes> <intermediate bytes> <final byte>

local CSI_INTRODUCER = "\\e\\[" -- ESC [
local PARAM_BYTES = "[\\x30-\\x3F]" -- 0-9 : ; < = > ?
local INTERMEDIATE_BYTES = "[\\x20-\\x2F]" -- space ! " # $ % & ' ( ) * + , - . /
local FINAL_BYTES = "[\\x40-\\x7E]" -- @ A-Z [ \ ] ^ _ ` a-z { | } ~
local FINAL_BYTES_NON_SGR = "[\\x40-\\x6C\\x6E-\\x7E]" -- same as FINAL_BYTES but without m [color ending byte] (0x6D, SGR)

-- OSC (Operating System Command) structure:
--   ESC ] <prefix bytes> <text bytes> <terminator>

local OSC_INTRODUCER = "\\e\\]" -- ESC ]
local OSC_PREFIX_BYTES = "[\\x08-\\x0D]*" -- BS HT LF VT FF CR (control characters)
local OSC_TEXT_BYTES = "[\\x20-\\x7E]*" -- space through ~ (printable ASCII)
local OSC_BEL_TERMINATOR = "\\x07" -- BEL (bell character, 0x07)
local OSC_ST_TERMINATOR = "\\e\\\\" -- ESC \ (string terminator)
local OSC_TERMINATOR = "\\(" .. OSC_BEL_TERMINATOR .. "\\|" .. OSC_ST_TERMINATOR .. "\\)" -- BEL or ST

-- Composed patterns: match complete CSI/OSC sequences for stripping

local CSI_COMPLETE_PATTERN = CSI_INTRODUCER .. PARAM_BYTES .. "*" .. INTERMEDIATE_BYTES .. "*" .. FINAL_BYTES
local CSI_NON_SGR_PATTERN = CSI_INTRODUCER .. PARAM_BYTES .. "*" .. INTERMEDIATE_BYTES .. "*" .. FINAL_BYTES_NON_SGR
local OSC_PATTERN = OSC_INTRODUCER .. OSC_PREFIX_BYTES .. OSC_TEXT_BYTES .. OSC_TERMINATOR

-- Partial patterns: match incomplete sequences at end of input.
-- These are buffered and reassembled when the next chunk of data arrives.

local OR_LONE_ESCAPE = "\\|\\e$" -- alternation: OR lone ESC at end of input
local NOT_OSC_TERMINATOR = "[^\\x07\\e\\\\]" -- not BEL (0x07) and not ESC (start of ST)

local PARTIAL_CSI_PATTERN = CSI_INTRODUCER .. PARAM_BYTES .. "*" .. INTERMEDIATE_BYTES .. "*" .. "$" .. OR_LONE_ESCAPE
local PARTIAL_OSC_PATTERN = OSC_INTRODUCER .. NOT_OSC_TERMINATOR .. "*$"

local L_ESC = "\x1b"
local L_OSC_INTRO = L_ESC .. "%]"
local L_OSC_CMD = "(%d+)"
local L_OSC_SEP = ";"
local L_OSC_DATA = "([^\x07\x1b]-)" -- non-greedy, no BEL or ESC
local L_BEL = "\x07"
local L_ST = L_ESC .. "\\"

local OSC_LUA_BEL = L_OSC_INTRO .. L_OSC_CMD .. L_OSC_SEP .. L_OSC_DATA .. L_BEL
local OSC_LUA_ST = L_OSC_INTRO .. L_OSC_CMD .. L_OSC_SEP .. L_OSC_DATA .. L_ST

--- OSC handler table: maps command number to function wich processes the data in the OSC sequence.
local partial_buffer = ""
local mode = "render"
local osc_handlers = {}
---@type table?
local baleia_instance = nil
local rx_partial_csi = vim.regex(PARTIAL_CSI_PATTERN)
local rx_partial_osc = vim.regex(PARTIAL_OSC_PATTERN)
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
	return vim.fn.substitute(line, CSI_COMPLETE_PATTERN, "", "g")
end

---Strip non-SGR CSI sequences from a line, keeping SGR (color) sequences intact.
---@param line string
---@return string
local function strip_non_sgr_csi(line)
	return vim.fn.substitute(line, CSI_NON_SGR_PATTERN, "", "g")
end

---Strip all OSC sequences from a line.
---@param line string
---@return string
local function strip_osc(line)
	return vim.fn.substitute(line, OSC_PATTERN, "", "g")
end

local function process_osc(line)
	line = line:gsub(OSC_LUA_BEL, function(cmd, data)
		local handler = osc_handlers[tonumber(cmd)]
		if handler then
			return handler(data)
		end
		return ""
	end)
	line = line:gsub(OSC_LUA_ST, function(cmd, data)
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
---@return integer|nil start_pos 0-indexed byte position where partial begins, or nil
local function check_partial(line)
	local csi = rx_partial_csi:match_str(line)
	local osc = rx_partial_osc:match_str(line)
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
		partial_buffer = last:sub(partial_start + 1)
		lines[#lines] = last:sub(1, partial_start)
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
	---@cast baleia_instance table
	baleia_instance:buf_set_lines(bufnr, start, end_, false, lines)
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

return M
