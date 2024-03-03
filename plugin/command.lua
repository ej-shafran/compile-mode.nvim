vim.api.nvim_create_user_command(
	"Compile",
	require("compile-mode").compile,
	{ nargs = "?", complete = "shellcmd", bang = true, count = true }
)
vim.api.nvim_create_user_command("Recompile", require("compile-mode").recompile, { bang = true, count = true })
vim.api.nvim_create_user_command("NextError", require("compile-mode").next_error, {})
vim.api.nvim_create_user_command("PrevError", require("compile-mode").prev_error, {})

vim.api.nvim_create_autocmd({ "FileType" }, {
	pattern = "compilation",
	group = vim.api.nvim_create_augroup("compile-mode-commands", { clear = true }),
	callback = function()
		local bufnr = vim.fn.bufnr(require("compile-mode").config.buffer_name)
		vim.api.nvim_buf_create_user_command(bufnr, "CompileGotoError", require("compile-mode").goto_error, {})
		vim.api.nvim_buf_create_user_command(bufnr, "CompileInterrupt", require("compile-mode").interrupt, {})
	end,
})
