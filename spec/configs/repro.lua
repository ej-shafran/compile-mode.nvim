local root = vim.fn.fnamemodify("./.repro", ":p")

-- set stdpaths to use .repro
for _, name in ipairs({ "config", "data", "state", "cache" }) do
	vim.env[("XDG_%s_HOME"):format(name:upper())] = root .. "/" .. name
end

-- bootstrap lazy
local lazypath = root .. "/plugins/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
	vim.fn.system({
		"git",
		"clone",
		"--filter=blob:none",
		"--single-branch",
		"https://github.com/folke/lazy.nvim.git",
		lazypath,
	})
end
vim.opt.runtimepath:prepend(lazypath)

-- install plugins
local compile_mode_lazy_spec = {
	"ej-shafran/compile-mode.nvim",
	branch = "latest",
	-- or a specific version:
	-- tag = "v4.0.0"
	dependencies = {
		"nvim-lua/plenary.nvim",
		-- if you want to enable coloring of ANSI escape codes in
		-- compilation output, add:
		-- { "m00qek/baleia.nvim", tag = "v1.3.0" },
	},
	config = function()
		--- add configuration options here
		---@type CompileModeOpts
		vim.g.compile_mode = {
			-- to add ANSI escape code support, add:
			-- baleia_setup = true,

			-- to make `:Compile` replace special characters (e.g. `%`) in
			-- the command (and behave more like `:!`), add:
			-- bang_expansion = true,
		}
	end,
}
local plugins = {
	"folke/tokyonight.nvim",
	compile_mode_lazy_spec,
}
require("lazy").setup(plugins, {
	root = root .. "/plugins",
})

-- additional
vim.opt.termguicolors = true
vim.cmd([[colorscheme tokyonight]])
