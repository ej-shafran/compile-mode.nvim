local compile_mode = require("compile-mode")

local matchadd = vim.fn.matchadd

local function command(cmd, expr, opts)
	vim.api.nvim_buf_create_user_command(0, cmd, expr, opts or {})
end

local function set(mode, key, expr, opts)
	vim.keymap.set(mode, key, expr, vim.tbl_extend("force", opts, { buffer = 0 }))
end

matchadd("CompileModeInfo", "^Compilation \\zsfinished\\ze.*")
matchadd(
	"CompileModeError",
	"^Compilation \\zs\\(exited abnormally\\|interrupted\\|killed\\|terminated\\|segmentation fault\\)\\ze"
)
matchadd("CompileModeError", "^Compilation .* with code \\zs[0-9]\\+\\ze")
matchadd("CompileModeOutputFile", " --\\?o\\(utfile\\|utput\\)\\?[= ]\\zs\\(\\S\\+\\)\\ze")
matchadd(
	"CompileModeCheckTarget",
	"^[Cc]hecking \\([Ff]or \\|[Ii]f \\|[Ww]hether \\(to\\)\\?\\)\\?\\zs\\(.\\+\\)\\ze\\.\\.\\."
)
matchadd(
	"CompileModeCheckResult",
	"^[Cc]hecking \\([Ff]or \\|[Ii]f \\|[Ww]hether \\(to\\)\\?\\)\\?\\(.\\+\\)\\.\\.\\. *\\((cached) *\\)\\?\\zs.*\\ze"
)
matchadd(
	"CompileModeInfo",
	"^[Cc]hecking \\([Ff]or \\|[Ii]f \\|[Ww]hether \\(to\\)\\?\\)\\?\\(.\\+\\)\\.\\.\\. *\\((cached) *\\)\\?\\zsyes\\( .\\+\\)\\?\\ze$"
)
matchadd(
	"CompileModeError",
	"^[Cc]hecking \\([Ff]or \\|[Ii]f \\|[Ww]hether \\(to\\)\\?\\)\\?\\(.\\+\\)\\.\\.\\. *\\((cached) *\\)\\?\\zsno\\ze$"
)
matchadd("CompileModeDirectoryMessage", "\\(Entering\\|Leaving\\) directory [`']\\zs.\\+\\ze'$")

command("CompileGotoError", compile_mode.goto_error)
command("CompileInterrupt", compile_mode.interrupt)
command("CompileNextError", compile_mode.move_to_next_error, { count = 1 })
command("CompileNextFile", compile_mode.move_to_next_file, { count = 1 })
command("CompilePrevError", compile_mode.move_to_prev_error, { count = 1 })
command("CompilePrevFile", compile_mode.move_to_prev_file, { count = 1 })

set("n", "q", "<cmd>q<cr>", { silent = true })
set("n", "<cr>", "<cmd>CompileGotoError<cr>", { silent = true })
set("n", "<C-c>", "<cmd>CompileInterrupt<cr>", { silent = true })
