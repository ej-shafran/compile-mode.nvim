vim.api.nvim_create_user_command(
	"Compile",
	require("compile-mode").compile,
	{ nargs = "?", complete = "shellcmd", bang = true, count = true }
)
vim.api.nvim_create_user_command("Recompile", require("compile-mode").recompile, { bang = true, count = true })
vim.api.nvim_create_user_command("NextError", require("compile-mode").next_error, {})
vim.api.nvim_create_user_command("PrevError", require("compile-mode").prev_error, {})
