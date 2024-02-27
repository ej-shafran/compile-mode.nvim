local M = {}

---@type fun(name: string, create: boolean?): integer
M.get_bufnr = vim.fn.bufnr
---@type fun(bufnr: integer, opt: string, value: any)
---@diagnostic disable-next-line: undefined-field
M.buf_set_opt = vim.api.nvim_buf_set_option

function M.get_compilation_bufnr()
	return M.get_bufnr("*compilation*")
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
	end, 30)
	coroutine.yield(co)
end

return M
