local command = vim.api.nvim_create_user_command
local compile_mode = require("compile-mode")

command("Compile", compile_mode.compile, { nargs = "?", complete = "shellcmd", bang = true, count = true })
command("Recompile", compile_mode.recompile, { bang = true, count = true })
command("NextError", compile_mode.next_error, {})
command("PrevError", compile_mode.prev_error, {})
command("CurrentError", compile_mode.current_error, {})
command("QuickfixErrors", function()
	compile_mode.send_to_qflist()
	vim.cmd("botright copen")
end, {})
