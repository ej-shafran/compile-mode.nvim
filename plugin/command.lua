vim.api.nvim_create_user_command("Compile", require("compile-mode").compile, { nargs = "?", complete = "shellcmd" })
vim.api.nvim_create_user_command("Recompile", require("compile-mode").recompile, {})
