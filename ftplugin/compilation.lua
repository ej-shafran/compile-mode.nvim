local compile_mode = require("compile-mode")

if compile_mode.config.baleia_setup then
	local ok, baleia_mod = pcall(require, "baleia")
	if ok then
		local opts = {}
		if type(compile_mode.config.baleia_setup) == "table" then
			opts = compile_mode.config.baleia_setup --[[@as table]]
		end

		local baleia = baleia_mod.setup(opts)
		baleia.automatically(0)
	end
end

local matchadd = vim.fn.matchadd

local function command(cmd, expr, opts)
	vim.api.nvim_buf_create_user_command(0, cmd, expr, opts or {})
end

local function set(mode, key, expr, opts)
	vim.keymap.set(mode, key, expr, vim.tbl_extend("force", { silent = true }, opts or {}, { buffer = 0 }))
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

set("n", "q", "<cmd>q<cr>")
set("n", "<cr>", "<cmd>CompileGotoError<cr>")
set("n", "<C-c>", "<cmd>CompileInterrupt<cr>")
set("n", "<C-q>", "<cmd>QuickfixErrors<cr>")
set("n", "<C-r>", "<cmd>Recompile<cr>")
set("n", "<C-g>n", "<cmd>CompileNextError<cr>")
set("n", "<C-g>p", "<cmd>CompilePrevError<cr>")
set("n", "<C-g>]", "<cmd>CompileNextFile<cr>")
set("n", "<C-g>[", "<cmd>CompilePrevFile<cr>")
set("n", "gf", compile_mode._gf)
set("n", "<C-w>f", compile_mode._CTRL_W_f)
