vim.api.nvim_create_user_command("Compile", require("compile-mode").compile, { nargs = "?", complete = "shellcmd" })
vim.api.nvim_create_user_command("Recompile", require("compile-mode").recompile, {})

vim.api.nvim_create_autocmd({ "FileType" }, {
	pattern = "compilation",
	callback = function()
		vim.api.nvim_buf_create_user_command(0, "CompileGotoError", require("compile-mode").goto_error, {})
	end,
})
