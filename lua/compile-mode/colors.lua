---@alias HighlightStyle { background: string?, foreground: string?, gui: string? }

local M = {}

local default_colors = {
	[0] = "Black",
	[1] = "DarkRed",
	[2] = "DarkGreen",
	[3] = "DarkYellow",
	[4] = "DarkBlue",
	[5] = "DarkMagenta",
	[6] = "DarkCyan",
	[7] = "LightGrey",
	[8] = "DarkGrey",
	[9] = "LightRed",
	[10] = "LightGreen",
	[11] = "LightYellow",
	[12] = "LightBlue",
	[13] = "LightMagenta",
	[14] = "LightCyan",
	[15] = "White",
}

local theme = {}

for index = 0, 255 do
	local color = vim.g["terminal_color_" .. index]
	theme[index] = color or default_colors[index]
end

M.default_highlights = {
	error = {
		gui = "underline",
	},
	error_row = {
		gui = "underline",
		foreground = theme[2],
	},
	error_col = {
		gui = "underline",
		foreground = theme[8],
	},
	error_filename = {
		gui = "bold,underline",
		foreground = theme[9],
	},
	warning_filename = {
		gui = "underline",
		foreground = theme[3],
	},
	info_filename = {
		gui = "underline",
		foreground = theme[14],
	},
}

---If the given highlight group is not defined, define it.
---@param group_name string
---@param styles HighlightStyle
local function create_hlgroup(group_name, styles)
	---@diagnostic disable-next-line: undefined-field
	local success, existing = pcall(vim.api.nvim_get_hl_by_name, group_name, true)

	if not success or not existing.foreground or not existing.background then
		local hlgroup = "default " .. group_name

		if styles.background then
			hlgroup = hlgroup .. " guibg=" .. styles.background
		end

		if styles.foreground then
			hlgroup = hlgroup .. " guifg=" .. styles.foreground
		end

		if styles.gui then
			hlgroup = hlgroup .. " gui=" .. styles.gui
		end

		if not styles.background and not styles.gui and not styles.foreground then
			hlgroup = hlgroup .. " guifg=NONE"
		end

		vim.cmd.highlight(hlgroup)
	end
end

function M.setup_highlights(highlights)
	create_hlgroup("CompileModeError", highlights.error or {})
	create_hlgroup("CompileModeErrorRow", highlights.error_row or {})
	create_hlgroup("CompileModeErrorCol", highlights.error_col or {})

	create_hlgroup("CompileModeErrorFilename", highlights.error_filename or {})
	create_hlgroup("CompileModeWarningFilename", highlights.warning_filename or {})
	create_hlgroup("CompileModeInfoFilename", highlights.info_filename or {})
end

return M
