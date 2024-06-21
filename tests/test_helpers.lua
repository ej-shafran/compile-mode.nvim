local M = {}

---@param bufnr integer
---@param opt string
---@param value any
function M.buf_set_opt(bufnr, opt, value)
	vim.api.nvim_set_option_value(opt, value, { buf = bufnr })
end

function M.get_compilation_bufnr()
	return vim.fn.bufnr(vim.fn.fnameescape("*compilation*"))
end

---@param opts Config|nil
function M.setup_tests(opts)
	require("plugin.command")
	require("compile-mode").setup(opts or {})
end

function M.wait()
	local co = coroutine.running()
	vim.defer_fn(function()
		coroutine.resume(co)
	end, 100)
	coroutine.yield(co)
end

return M
