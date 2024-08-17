local command = vim.api.nvim_create_user_command
local compile_mode = require("compile-mode")

command("Compile", compile_mode.compile, {
	nargs = "?",
	bang = true,
	count = true,
	complete = function(_, cmdline)
		local cmd = cmdline:gsub("Compile%s+", "")
		local results = vim.fn.getcompletion(("!%s"):format(cmd), "cmdline")
		return results
	end,
})
command("Recompile", compile_mode.recompile, { bang = true, count = true })
command("NextError", compile_mode.next_error, { count = 1 })
command("PrevError", compile_mode.prev_error, { count = 1 })
command("CurrentError", compile_mode.current_error, {})
command("QuickfixErrors", function()
	compile_mode.send_to_qflist()
	vim.cmd("botright copen")
end, {})
