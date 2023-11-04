---@alias StringRange { start: integer, end_: integer }
---@alias Error { highlighted: boolean, level: level, full: StringRange, filename: { value: string, range: StringRange }, row: { value: integer, range: StringRange }?, end_row: { value: integer, range: StringRange }?, col: { value: integer, range: StringRange }?, end_col: { value: integer, range: StringRange }? }

local utils = require("compile-mode.utils")

local M = {}

---@enum level
local level = {
	ERROR = 2,
	WARNING = 1,
	INFO = 0,
}

---@type table<integer, Error>
M.error_list = {}

---TODO: document
---(REGEXP FILE [LINE COLUMN TYPE HYPERLINK HIGHLIGHT...])
---@type table<string, { [1]: string, [2]: integer, [3]: integer|IntByInt|nil, [4]: integer|IntByInt|nil, [5]: nil|0|1|2|IntByInt }>
M.error_regexp_table = {
	-- TODO: use the actual alist from Emacs
	gnu = {
		"^\\%([[:alpha:]][-[:alnum:].]\\+: \\?\\|[ 	]\\%(in \\| from\\)\\)\\?\\(\\%([0-9]*[^0-9\\n]\\)\\%([^\\n :]\\| [^-/\\n]\\|:[^ \\n]\\)\\{-}\\)\\%(: \\?\\)\\([0-9]\\+\\)\\%(-\\([0-9]\\+\\)\\%(\\.\\([0-9]\\+\\)\\)\\?\\|[.:]\\([0-9]\\+\\)\\%(-\\%(\\([0-9]\\+\\)\\.\\)\\([0-9]\\+\\)\\)\\?\\)\\?:\\%( *\\(\\%(FutureWarning\\|RuntimeWarning\\|W\\%(arning\\)\\|warning\\)\\)\\| *\\([Ii]nfo\\%(\\>\\|formationa\\?l\\?\\)\\|I:\\|\\[ skipping .\\+ ]\\|instantiated from\\|required from\\|[Nn]ote\\)\\| *\\%([Ee]rror\\)\\|\\%([0-9]\\?\\)\\%([^0-9\\n]\\|$\\)\\|[0-9][0-9][0-9]\\)",
		1,
		{ 2, 3 },
		{ 5, 4 },
		{ 8, 9 },
	},
	oracle = {
		"^\\%(Semantic error\\|Error\\|PCC-[0-9]\\+:\\).* line \\([0-9]\\+\\)\\%(\\%(,\\| at\\)\\? column \\([0-9]\\+\\)\\)\\?\\%(,\\| in\\| of\\)\\? file \\(.\\{-}\\):\\?$",
		3,
		1,
		2,
	},
}

---Given a `matchlistpos` result and a capture-group matcher, return the location of the relevant capture group(s).
---
---@param result (StringRange|nil)[]
---@param group integer|IntByInt|nil
---@return StringRange|nil
---@return StringRange|nil
local function parse_matcher_group(result, group)
	if not group then
		return nil
	elseif type(group) == "number" then
		return result[group + 1]
	elseif type(group) == "table" then
		local first = group[1] + 1
		local second = group[2] + 1

		return result[first], result[second]
	end
end

local function range_and_value(line, range)
	return {
		value = line:sub(range.start, range.end_),
		range = range,
	}
end

local function numeric_range_and_value(line, range)
	if not range then
		return nil
	end

	local raw = range_and_value(line, range)

	raw.value = tonumber(raw.value)
	if not raw.value then
		return nil
	end

	return raw
end

local function parse_matcher(matcher, line)
	local regex = matcher[1]
	local result = utils.matchlistpos(line, regex)
	if not result then
		return nil
	end

	local filename_range = result[matcher[2] + 1]
	if not filename_range then
		return nil
	end

	local row_range, end_row_range = parse_matcher_group(result, matcher[3])
	local col_range, end_col_range = parse_matcher_group(result, matcher[4])

	local error_level
	if not matcher[5] then
		error_level = level.ERROR
	elseif type(matcher[5]) == "number" then
		level = matcher[5]
	elseif type(matcher[5]) == "table" then
		if result[matcher[5][1] + 1] then
			error_level = level.WARNING
		elseif result[matcher[5][2] + 1] then
			error_level = level.INFO
		else
			error_level = level.ERROR
		end
	end

	return {
		highlighted = false,
		level = error_level,
		full = result[1],
		filename = range_and_value(line, filename_range),
		row = numeric_range_and_value(line, row_range),
		col = numeric_range_and_value(line, col_range),
		end_row = numeric_range_and_value(line, end_row_range),
		end_col = numeric_range_and_value(line, end_col_range),
	}
end

---Parses error syntax from a given line.
---@param line string the line to parse
---@return Error|nil
function M.parse(line)
	for _, matcher in pairs(M.error_regexp_table) do
		local result = parse_matcher(matcher, line)
		if result then
			return result
		end
	end

	return nil
end

---Highlight a single error in the compilation buffer.
---@param bufnr integer
---@param error Error
---@param linenum integer
local function highlight_error(bufnr, error, linenum)
	if error.highlighted then
		return
	end

	error.highlighted = true

	local full_range = error.full
	utils.add_highlight(bufnr, "CompileModeError", linenum, full_range)

	local hlgroup = "CompileMode"
	if error.level == level.WARNING then
		hlgroup = hlgroup .. "Warning"
	elseif error.level == level.INFO then
		hlgroup = hlgroup .. "Info"
	else
		hlgroup = hlgroup .. "Error"
	end
	hlgroup = hlgroup .. "Filename"

	local filename_range = error.filename.range
	utils.add_highlight(bufnr, hlgroup, linenum, filename_range)

	local row_range = error.row and error.row.range
	if row_range then
		utils.add_highlight(bufnr, "CompileModeErrorRow", linenum, row_range)
	end
	local end_row_range = error.end_row and error.end_row.range
	if end_row_range then
		utils.add_highlight(bufnr, "CompileModeErrorRow", linenum, end_row_range)
	end

	local col_range = error.col and error.col.range
	if col_range then
		utils.add_highlight(bufnr, "CompileModeErrorCol", linenum, col_range)
	end
	local end_col_range = error.end_col and error.end_col.range
	if end_col_range then
		utils.add_highlight(bufnr, "CompileModeErrorCol", linenum, end_col_range)
	end
end

---Highlight all errors in the compilation buffer.
---@param bufnr integer
function M.highlight(bufnr)
	for linenum, error in pairs(M.error_list) do
		highlight_error(bufnr, error, linenum)
	end
end

return M
