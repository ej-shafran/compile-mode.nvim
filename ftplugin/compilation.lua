local compile_mode = require("compile-mode")
local config = require("compile-mode.config.internal")
local log = require("compile-mode.log")

local bufnr = vim.api.nvim_get_current_buf()

if config.baleia_setup then
	local ok, baleia_mod = pcall(require, "baleia")
	if ok then
		local opts = {}
		if type(config.baleia_setup) == "table" then
			opts = config.baleia_setup --[[@as table]]
		end

		local baleia = baleia_mod.setup(opts)
		baleia.automatically(bufnr)
	else
		log.warn(
			"Could not require `baleia`, but `baleia_setup` was passed. Did you forget to install `baleia` for color code support?"
		)
	end
end

local matchadd = vim.fn.matchadd

---@param cmd string
---@param expr string|function
---@param opts vim.api.keyset.user_command|nil
local function command(cmd, expr, opts)
	vim.api.nvim_buf_create_user_command(bufnr, cmd, expr, opts or {})
end

---@param mode string
---@param key string
---@param expr string|function
---@param opts vim.keymap.set.Opts|nil
local function set(mode, key, expr, opts)
	vim.keymap.set(mode, key, expr, vim.tbl_extend("force", { silent = true }, opts or {}, { buffer = bufnr }))
end

---@param event string|string[]
---@param opts vim.api.keyset.create_autocmd
local function autocmd(event, opts)
	vim.api.nvim_create_autocmd(
		event,
		vim.tbl_extend("force", {
			group = vim.api.nvim_create_augroup("compile-mode.nvim", { clear = false }),
		}, opts)
	)
end

vim.g.compilation_buffer = bufnr

compile_mode._parse_errors(bufnr)

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
command("CompileDebugError", compile_mode.debug_error)
command("CompileInterrupt", compile_mode.interrupt)
command("CompileCloseBuffer", compile_mode.close_buffer)
command("CompileNextError", compile_mode.move_to_next_error, { count = 1 })
command("CompileNextFile", compile_mode.move_to_next_file, { count = 1 })
command("CompilePrevError", compile_mode.move_to_prev_error, { count = 1 })
command("CompilePrevFile", compile_mode.move_to_prev_file, { count = 1 })

set("n", "<cr>", "<cmd>CompileGotoError<cr>")
set("n", "<LeftMouse>", "<LeftMouse><cmd>CompileGotoError<cr>")
set("n", "<C-/>", "<cmd>CompileDebugError<cr>")
set("n", "<C-c>", "<cmd>CompileInterrupt<cr>")
set("n", "q", "<cmd>CompileCloseBuffer<cr>")
set("n", "<C-q>", "<cmd>QuickfixErrors<cr>")
set("n", "<C-r>", "<cmd>Recompile<cr>")
set("n", "<Tab>", "<cmd>CompileNextError<cr>")
set("n", "<S-Tab>", "<cmd>CompilePrevError<cr>")
set("n", "<C-g>n", "<cmd>CompileNextError<cr>")
set("n", "<C-g>p", "<cmd>CompilePrevError<cr>")
set("n", "<C-g>]", "<cmd>CompileNextFile<cr>")
set("n", "<C-g>[", "<cmd>CompilePrevFile<cr>")
set("n", "gf", compile_mode._gf)
set("n", "<C-w>f", compile_mode._CTRL_W_f)
set("n", "<C-g>f", "<cmd>NextErrorFollow<cr>")

autocmd("CursorMoved", {
	desc = "Next Error Follow",
	buffer = bufnr,
	callback = compile_mode._follow_cursor,
})

autocmd({ "TextChanged", "TextChangedI" }, {
	desc = "Error Parsing",
	buffer = bufnr,
	callback = function()
		compile_mode._parse_errors(bufnr)
	end,
})
