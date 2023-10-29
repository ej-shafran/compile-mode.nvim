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

---TODO: this probably needs to return a string
---TODO: this should be more flexible
---Given a `:h matchlist()` result and a capture-group matcher, return the relevant capture group.
---
---@param result string[]
---@param group integer|IntByInt|nil
---@return integer|nil
local function parse_matcher_group(result, group)
	if not group then
		return nil
	elseif type(group) == "number" then
		return result[group + 1] ~= "" and tonumber(result[group + 1]) or nil
	elseif type(group) == "table" then
		local first = group[1] + 1
		local second = group[2] + 1

		if result[first] and result[first] ~= "" then
			return tonumber(result[first])
		elseif result[second] and result[second] ~= "" then
			return tonumber(result[second])
		else
			return nil
		end
	end
end

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

	local filename = result[matcher[2] + 1]
	local r = parse_matcher_group(result, matcher[3])
	local c = parse_matcher_group(result, matcher[4])

	return true, filename, r or 1, c or 1
end

return M
