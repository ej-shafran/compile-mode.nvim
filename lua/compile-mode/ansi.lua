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

local PARTIAL_CSI_PATTERN = CSI_INTRODUCER .. PARAM_BYTES .. "*" .. INTERMEDIATE_BYTES .. "*" .. OR_LONE_ESCAPE
local PARTIAL_OSC_PATTERN = OSC_INTRODUCER .. NOT_OSC_TERMINATOR .. "*$"

local M = {}

local partial_buffer = ""

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

---Strip all CSI and OSC sequences from a line (no colors).
---@param line string
---@return string
local function filter_line(line)
	return strip_csi(strip_osc(line))
end

---Strip non-SGR CSI and OSC sequences, keeping SGR for baleia color rendering.
---@param line string
---@return string
local function filter_color_line(line)
	return strip_non_sgr_csi(strip_osc(line))
end

---Process a single line based on the ANSI mode.
---@param line string
---@param mode "filter"|"render"|nil
---@return string
local function process_line(line, mode)
	if mode == "filter" then
		return filter_line(line)
	elseif mode == "render" then
		return filter_color_line(line)
	else
		return line
	end
end

---Process a list of lines, handling partial escape sequences across chunks.
---Incomplete sequences at the end of the last line are buffered and prepended
---to the first line of the next call.
---@param lines string[]
---@param mode "filter"|"render"|nil
---@return string[]
function M.process_lines(lines, mode)
	if not mode then
		return lines
	end

	local result = {}

	local first_line = partial_buffer .. lines[1]
	partial_buffer = ""

	for i, line in ipairs(lines) do
		if i == 1 then
			line = first_line
		end

		line = process_line(line, mode)
		result[i] = line
	end

	local last_line = result[#result]
	if last_line then
		local partial_csi_rx = vim.regex(PARTIAL_CSI_PATTERN)
		local partial_osc_rx = vim.regex(PARTIAL_OSC_PATTERN)

		local csi_start = partial_csi_rx:match_str(last_line)
		local osc_start = partial_osc_rx:match_str(last_line)

		if csi_start then
			partial_buffer = last_line:sub(csi_start + 1)
			result[#result] = last_line:sub(1, csi_start)
		elseif osc_start then
			partial_buffer = last_line:sub(osc_start + 1)
			result[#result] = last_line:sub(1, osc_start)
		end
	end

	return result
end

---Reset the partial sequence buffer. Called when a new compilation starts.
function M.reset()
	partial_buffer = ""
end

return M
