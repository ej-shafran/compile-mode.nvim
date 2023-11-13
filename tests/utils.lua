local M = {}

---@type fun(name: string, create: boolean?): integer
M.get_bufnr = vim.fn.bufnr
---@type fun(bufnr: integer, opt: string, value: any)
---@diagnostic disable-next-line: undefined-field
M.buf_set_opt = vim.api.nvim_buf_set_option

---@param opts Config|nil options to pass to `setup()`
function M.setup_tests(opts)
	require("plugin.command")
	require("compile-mode").setup(opts or {})
end

---@param ms number milliseconds to wait
function M.halt_test(ms)
	local co = coroutine.running()
	vim.defer_fn(function()
		coroutine.resume(co)
	end, ms)
	coroutine.yield(co)
end

return M
