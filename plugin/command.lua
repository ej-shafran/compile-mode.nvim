vim.api.nvim_create_user_command(
	"Compile",
	require("compile-mode").compile,
	{ nargs = "?", complete = "shellcmd", bang = true }
)
vim.api.nvim_create_user_command("Recompile", require("compile-mode").recompile, { bang = true })
vim.api.nvim_create_user_command("NextError", require("compile-mode").next_error, {})
vim.api.nvim_create_user_command("PrevError", require("compile-mode").prev_error, {})

vim.api.nvim_create_autocmd({ "FileType" }, {
	pattern = "compilation",
	callback = function()
		vim.api.nvim_buf_create_user_command(0, "CompileGotoError", require("compile-mode").goto_error, {})
	end,
})
