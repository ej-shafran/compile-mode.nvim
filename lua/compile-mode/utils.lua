---@alias IntByInt { [1]: integer, [2]: integer }

local a = require("plenary.async")

local M = {}

local compile_mode_ns = vim.api.nvim_create_namespace("compile-mode.nvim")

---@param bufnr integer
---@param hlname string
---@param linenum integer
---@param range StringRange
function M.add_highlight(bufnr, hlname, linenum, range)
	vim.api.nvim_buf_add_highlight(bufnr, compile_mode_ns, hlname, linenum - 1, range.start - 1, range.end_)
end

---@param input string
---@param pattern string
---@return (StringRange|nil)[]
function M.matchlistpos(input, pattern)
	local list = vim.fn.matchlist(input, pattern) --[[@as string[] ]]

	---@type (IntByInt|nil)[]
	local result = {}

	local latest_index = vim.fn.match(input, pattern)
	for i, capture in ipairs(list) do
		if capture == "" then
			result[i] = nil
		else
			local start, end_ = string.find(input, capture, latest_index, true)
			assert(start and end_)
			if i ~= 1 then
				latest_index = end_ + 1
			end
			result[i] = {
				start = start,
				end_ = end_,
			}
		end
	end

	return result
end

---@type fun(opts: table): string
M.input = a.wrap(vim.ui.input, 2)

---@type fun()
M.wait = a.wrap(vim.schedule, 1)

---@type fun(ms: number)
M.delay = a.wrap(function(timeout, callback)
	vim.defer_fn(callback, timeout)
end, 2)

---@type fun(bufnr: integer, opt: string, value: any)
---@diagnostic disable-next-line: undefined-field
M.buf_set_opt = vim.api.nvim_buf_set_option

---If `fname` has a window open, do nothing.
---Otherwise, split a new window (and possibly buffer) open for that file, respecting `config.split_vertically`.
---
---@param fname string
---@param smods SMods
---@param count integer
---@return integer bufnr the identifier of the buffer for `fname`
function M.split_unless_open(fname, smods, count)
	local bufnum = vim.fn.bufnr(vim.fn.expand(fname) --[[@as any]]) --[[@as integer]]
	local winnum = vim.fn.bufwinnr(bufnum)

	if winnum == -1 then
		local cmd = fname
		if smods.vertical then
			cmd = "vsplit " .. cmd
		else
			cmd = "split " .. cmd
		end

		if count ~= 0 then
			cmd = count .. cmd
		end

		if smods.split and smods.split ~= "" then
			cmd = smods.split .. " " .. cmd
		end

		vim.cmd(cmd)
	end

	return vim.fn.bufnr(vim.fn.expand(fname) --[[@as any]]) --[[@as integer]]
end

---@param filename string
---@param error Error
local function goto_file(filename, error)
	local row = error.row and error.row.value or 1
	local end_row = error.end_row and error.end_row.value

	local col = (error.col and error.col.value or 1) - 1
	if col < 0 then
		col = 0
	end
	local end_col = error.end_col and error.end_col.value - 1
	if end_col and end_col < 0 then
		end_col = 0
	end

	vim.cmd.e(filename)
	local last_row = vim.api.nvim_buf_line_count(0)
	if row > last_row then
		row = last_row
	end
	vim.api.nvim_win_set_cursor(0, { row, col })

	if end_row or end_col then
		local cmd = ""
		if not error.col and not error.end_col then
			cmd = cmd .. "V"
		else
			cmd = cmd .. "v"
		end

		if end_row then
			cmd = cmd .. tostring(end_row - row) .. "j"
		end

		if end_col then
			cmd = cmd .. tostring(end_col - col) .. "l"
		end

		-- TODO: maybe use select mode by doing:
		-- cmd = cmd .. "gh"

		vim.cmd.normal(cmd)
	end
end

---@param error Error
---@type fun(error: Error)
M.jump_to_error = a.void(function(error)
	local file_exists = vim.fn.filereadable(error.filename.value) ~= 0

	if file_exists then
		goto_file(error.filename.value, error)
		return
	end

	local dir = M.input({
		prompt = "Find this error in: ",
		completion = "file",
	})
	if not dir then
		return
	end
	dir = dir:gsub("(.)/$", "%1")

	M.wait()

	if vim.fn.isdirectory(dir) == 0 then
		if vim.fn.filereadable(dir) == 0 then
			vim.notify(dir .. " is not readable", vim.log.levels.ERROR)
			return
		end

		goto_file(dir, error)
		return
	end

	local nested_filename = vim.fs.normalize(dir .. "/" .. error.filename.value)
	if vim.fn.filereadable(nested_filename) == 0 then
		vim.notify(error.filename.value .. " does not exist in " .. dir, vim.log.levels.ERROR)
		return
	end

	goto_file(nested_filename, error)
end)

return M
