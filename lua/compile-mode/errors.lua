local M = {}

---TODO: document
---(REGEXP FILE [LINE COLUMN TYPE HYPERLINK HIGHLIGHT...])
---@type table<string, { [1]: string, [2]: integer, [3]: integer|IntByInt|nil, [4]: integer|IntByInt|nil, [5]: nil|0|1|2 }>
M.error_regexp_table = {
	-- TODO: use the actual alist from Emacs
	gnu = {
		"^\\%([[:alpha:]][-[:alnum:].]\\+: \\?\\|[ 	]\\%(in \\| from\\)\\)\\?\\(\\%([0-9]*[^0-9\\n]\\)\\%([^\\n :]\\| [^-/\\n]\\|:[^ \\n]\\)\\{-}\\)\\%(: \\?\\)\\([0-9]\\+\\)\\%(-\\([0-9]\\+\\)\\%(\\.\\([0-9]\\+\\)\\)\\?\\|[.:]\\([0-9]\\+\\)\\%(-\\%(\\([0-9]\\+\\)\\.\\)\\([0-9]\\+\\)\\)\\?\\)\\?:\\%( *\\(\\%(FutureWarning\\|RuntimeWarning\\|W\\%(arning\\)\\|warning\\)\\)\\| *\\([Ii]nfo\\%(\\>\\|formationa\\?l\\?\\)\\|I:\\|\\[ skipping .\\+ ]\\|instantiated from\\|required from\\|[Nn]ote\\)\\| *\\%([Ee]rror\\)\\|\\%([0-9]\\?\\)\\%([^0-9\\n]\\|$\\)\\|[0-9][0-9][0-9]\\)",
		1,
		{ 2, 4 },
		{ 3, 5 },
		-- TODO: implement this
		nil,
	},
}

---Parses error syntax from a given line.
---@param line string the line to parse
---@return boolean ok whether there is an error here
---@return nil|string filename the filename for the error
---@return nil|integer r the row of the error
---@return nil|integer c the column of the error
function M.parse(line)
	local matcher = M.error_regexp_table["gnu"]
	local regex = matcher[1]
	local result = vim.fn.matchlist(line, regex)
	if not result or #result == 0 or result[1] == "" then
		return false, nil, nil, nil
	end

	local file_index = matcher[2] + 1
	local filename = result[file_index]

	local r
	local r_indices = matcher[3]
	if type(r_indices) == "number" then
		if result[r_indices + 1] and result[r_indices + 1] ~= "" then
			r = result[r_indices + 1]
		else
			return true, filename, 1, 1
		end
	elseif type(r_indices) == "table" then
		local first = r_indices[1] + 1
		local second = r_indices[2] + 1

		if result[first] and result[first] ~= "" then
			r = tonumber(result[first])
		elseif result[second] and result[second] ~= "" then
			r = tonumber(result[second])
		else
			return true, filename, 1, 1
		end
	else
		return true, filename, 1, 1
	end

	local c
	local c_indices = matcher[4]
	if type(c_indices) == "number" then
		if result[c_indices + 1] and result[c_indices + 1] ~= "" then
			c = result[c_indices + 1]
		else
			return true, filename, r, 1
		end
	elseif type(c_indices) == "table" then
		local first = c_indices[1] + 1
		local second = c_indices[2] + 1

		if result[first] and result[first] ~= "" then
			c = tonumber(result[first])
		elseif result[second] and result[second] ~= "" then
			c = tonumber(result[second])
		else
			return true, filename, r, 1
		end
	else
		return true, filename, r, 1
	end

	return true, filename, r, c
end


return M
