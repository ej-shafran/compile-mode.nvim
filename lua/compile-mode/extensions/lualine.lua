local M = {}

M.sections = {
	lualine_a = {
		function()
			return "Compilation"
		end,
	},
	lualine_b = {
		{
			function()
				return require("compile-mode").statusline_info().counts.error
			end,
			color = { fg = "Red" },
		},
		{
			function()
				return require("compile-mode").statusline_info().counts.warning
			end,
			color = { fg = "DarkYellow" },
		},
		{
			function()
				return require("compile-mode").statusline_info().counts.info
			end,
			color = { fg = "Green" },
		},
	},
	lualine_y = {
		function()
			local info = require("compile-mode").statusline_info()
			if info.status and info.status.type == "exit" then
				return ("Exit code %d"):format(info.status.code)
			else
				return ""
			end
		end,
	},
	lualine_z = {
		function()
			local info = require("compile-mode").statusline_info()

			if info.status and info.status.type == "exit" then
				return "Finished"
			else
				return "Running"
			end
		end,
	},
}

M.filetypes = { "compilation" }

return M
