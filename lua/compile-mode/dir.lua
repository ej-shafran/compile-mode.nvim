local M = {}

local utils = require("compile-mode.utils")

---
---The previous directory used for compilation.
---@type string|nil
M.compilation_directory = nil

---A table which keeps track of the changes in directory for the compilation buffer,
---based on "Entering directory" and "Leaving directory" messages.
---@type table<integer, string>
M.dir_changes = {}

---Get the directory to look in for a specific line in the compilation buffer,
---while respecting "Entering directory" and "Leaving directory" messages.
---@param linenum integer the line number to check the directory for
---@return string
function M.find_directory_for_line(linenum)
	local latest_linenum = nil
	local dir = M.compilation_directory or vim.fn.getcwd()
	for old_linenum, old_dir in pairs(M.dir_changes) do
		if old_linenum < linenum and (not latest_linenum or latest_linenum <= old_linenum) then
			latest_linenum = old_linenum
			dir = old_dir
		end
	end
	return dir
end

function M.resolve_filename(filename, linenum)
	if not linenum or utils.is_absolute(filename) then
		return filename
	end

	local dir = M.find_directory_for_line(linenum)
	return vim.fs.joinpath(dir, filename)
end

return M
