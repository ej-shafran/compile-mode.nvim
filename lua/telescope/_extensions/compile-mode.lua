local ok, telescope = pcall(require, "telescope")

if not ok then
	return
end

---@diagnostic disable-next-line: undefined-field
return telescope.register_extension({
	setup = function(ext_config, config)
		-- access extension config and user config
	end,
	exports = {
		["compile-mode"] = require("compile-mode.extensions.telescope"),
	},
})
