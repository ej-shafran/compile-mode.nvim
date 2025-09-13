local utils = require("compile-mode.utils")

local M = {}

---@enum CompileModeLevel
M.level = {
	ERROR = 2,
	WARNING = 1,
	INFO = 0,
}

---@type table<integer, CompileModeError>
M.error_list = {}

---This mirrors the `error_regexp_alist` variable from Emacs.
---See `error_regexp_table` in the README to understand this more in depth.
---
---@type table<string, CompileModeRegexpMatcher>
M.error_regexp_table = {
	absoft = {
		regex = '^\\%([Ee]rror on \\|[Ww]arning on\\( \\)\\)\\?[Ll]ine[ \t]\\+\\([0-9]\\+\\)[ \t]\\+of[ \t]\\+"\\?\\([a-zA-Z]\\?:\\?[^":\n]\\+\\)"\\?:',
		filename = 3,
		row = 2,
		type = { 1 },
	},
	ada = {
		regex = "\\(warning: .*\\)\\? at \\([^ \n]\\+\\):\\([0-9]\\+\\)$",
		filename = 2,
		row = 3,
		type = { 1 },
	},
	aix = {
		regex = " in line \\([0-9]\\+\\) of file \\([^ \n]\\+[^. \n]\\)\\.\\? ",
		filename = 2,
		row = 1,
	},
	ant = {
		regex = "^[ \t]*\\%(\\[[^] \n]\\+\\][ \t]*\\)\\{1,2\\}\\(\\%([A-Za-z]:\\)\\?[^: \n]\\+\\):\\([0-9]\\+\\):\\%(\\([0-9]\\+\\):\\([0-9]\\+\\):\\([0-9]\\+\\):\\)\\?\\( warning\\)\\?",
		filename = 1,
		row = { 2, 4 },
		col = { 3, 5 },
		type = { 6 },
	},
	bash = {
		regex = "^\\([^: \n\t]\\+\\): line \\([0-9]\\+\\):",
		filename = 1,
		row = 2,
	},
	borland = {
		regex = "^\\%(Error\\|Warnin\\(g\\)\\) \\%([FEW][0-9]\\+ \\)\\?\\([a-zA-Z]\\?:\\?[^:( \t\n]\\+\\) \\([0-9]\\+\\)\\%([) \t]\\|:[^0-9\n]\\)",
		filename = 2,
		row = 3,
		type = { 1 },
	},
	python_tracebacks_and_caml = {
		regex = '^[ \t]*File \\("\\?\\)\\([^," \n\t<>]\\+\\)\\1, lines\\? \\([0-9]\\+\\)-\\?\\([0-9]\\+\\)\\?\\%($\\|,\\%( characters\\? \\([0-9]\\+\\)-\\?\\([0-9]\\+\\)\\?:\\)\\?\\([ \n]Warning\\%( [0-9]\\+\\)\\?:\\)\\?\\)',
		filename = 2,
		row = { 3, 4 },
		col = { 5, 6 },
		type = { 7 },
	},
	cmake = {
		regex = "^CMake \\%(Error\\|\\(Warning\\)\\) at \\(.*\\):\\([1-9][0-9]*\\) ([^)]\\+):$",
		filename = 2,
		row = 3,
		type = { 1 },
	},
	cmake_info = {
		regex = "^  \\%( \\*\\)\\?\\(.*\\):\\([1-9][0-9]*\\) ([^)]\\+)$",
		filename = 1,
		row = 2,
		type = M.level.INFO,
	},
	comma = {
		regex = '^"\\([^," \n\t]\\+\\)", line \\([0-9]\\+\\)\\%([(. pos]\\+\\([0-9]\\+\\))\\?\\)\\?[:.,; (-]\\( warning:\\|[-0-9 ]*(W)\\)\\?',
		filename = 1,
		row = 2,
		col = 3,
		type = { 4 },
	},
	cucumber = {
		regex = "\\%(^cucumber\\%( -p [^[:space:]]\\+\\)\\?\\|#\\)\\%( \\)\\([^(].*\\):\\([1-9][0-9]*\\)",
		filename = 1,
		row = 2,
	},
	msft = {
		regex = "^ *\\([0-9]\\+>\\)\\?\\(\\%([a-zA-Z]:\\)\\?[^ :(\t\n][^:(\t\n]*\\)(\\([0-9]\\+\\)) \\?: \\%(see declaration\\|\\%(warnin\\(g\\)\\|[a-z ]\\+\\) C[0-9]\\+:\\)",
		filename = 2,
		row = 3,
		type = { 4 },
	},
	edg_1 = {
		regex = "^\\([^ \n]\\+\\)(\\([0-9]\\+\\)): \\%(error\\|warnin\\(g\\)\\|remar\\(k\\)\\)",
		filename = 1,
		row = 2,
		type = { 3, 4 },
	},
	edg_2 = {
		regex = 'at line \\([0-9]\\+\\) of "\\([^ \n]\\+\\)"$',
		filename = 2,
		row = 1,
		type = M.level.INFO,
	},
	epc = {
		regex = "^Error [0-9]\\+ at (\\([0-9]\\+\\):\\([^)\n]\\+\\))",
		filename = 2,
		row = 1,
	},
	ftnchek = {
		regex = "\\(^Warning .*\\)\\? line[ \n]\\([0-9]\\+\\)[ \n]\\%(col \\([0-9]\\+\\)[ \n]\\)\\?file \\([^ :;\n]\\+\\)",
		filename = 4,
		row = 2,
		col = 3,
		type = { 1 },
	},
	gradle_kotlin = {
		regex = "^\\%(\\(w\\)\\|.\\): *\\(\\%([A-Za-z]:\\)\\?[^:\n]\\+\\): *(\\([0-9]\\+\\), *\\([0-9]\\+\\))",
		filename = 2,
		row = 3,
		col = 4,
		type = { 1 },
	},
	iar = {
		regex = '^"\\(.*\\)",\\([0-9]\\+\\)\\s-\\+\\%(Error\\|Warnin\\(g\\)\\)\\[[0-9]\\+\\]:',
		filename = 1,
		row = 2,
		type = { 3 },
	},
	ibm = {
		regex = "^\\([^( \n\t]\\+\\)(\\([0-9]\\+\\):\\([0-9]\\+\\)) : \\%(warnin\\(g\\)\\|informationa\\(l\\)\\)\\?",
		filename = 1,
		row = 2,
		col = 3,
		type = { 4, 5 },
	},
	irix = {
		regex = '^[-[:alnum:]_/ ]\\+: \\%(\\%([sS]evere\\|[eE]rror\\|[wW]arnin\\(g\\)\\|[iI]nf\\(o\\)\\)[0-9 ]*: \\)\\?\\([^," \n\t]\\+\\)\\%(, line\\|:\\) \\([0-9]\\+\\):',
		filename = 3,
		row = 4,
		type = { 1, 2 },
	},
	java = {
		regex = "^\\%([ \t]\\+at \\|==[0-9]\\+== \\+\\%(at\\|b\\(y\\)\\)\\).\\+(\\([^()\n]\\+\\):\\([0-9]\\+\\))$",
		filename = 2,
		row = 3,
		type = { 1 },
	},
	jikes_file = {
		regex = '^\\%(Found\\|Issued\\) .* compiling "\\(.\\+\\)":$',
		filename = 1,
		type = M.level.INFO,
	},
	maven = {
		regex = "^\\%(\\[\\%(ERROR\\|\\(WARNING\\)\\|\\(INFO\\)\\)] \\)\\?\\([^\n []\\%([^\n :]\\| [^\n/-]\\|:[^\n []\\)*\\):\\[\\([[:digit:]]\\+\\),\\([[:digit:]]\\+\\)] ",
		filename = 3,
		row = 4,
		col = 5,
		type = { 1, 2 },
	},
	clang_include = {
		regex = "^In file included from \\([^\n:]\\+\\):\\([0-9]\\+\\):$",
		filename = 1,
		row = 2,
		type = M.level.INFO,
		priority = 2,
	},
	gcc_include = {
		regex = "^\\%(In file included \\|                 \\|\t\\)from \\([0-9]*[^0-9\n]\\%([^\n :]\\| [^-/\n]\\|:[^ \n]\\)\\{-}\\):\\([0-9]\\+\\)\\%(:\\([0-9]\\+\\)\\)\\?\\%(\\(:\\)\\|\\(,\\|$\\)\\)\\?",
		filename = 1,
		row = 2,
		col = 3,
		type = { 4, 5 },
	},
	["ruby_Test::Unit"] = {
		regex = "^    [[ ]\\?\\([^ (].*\\):\\([1-9][0-9]*\\)\\(\\]\\)\\?:in ",
		filename = 1,
		row = 2,
	},
	gmake = {
		regex = ": \\*\\*\\* \\[\\%(\\(.\\{-1,}\\):\\([0-9]\\+\\): .\\+\\)\\]",
		filename = 1,
		row = 2,
		type = M.level.INFO,
	},
	gnu = {
		regex = "^\\%([[:alpha:]][-[:alnum:].]\\+: \\?\\|[ \t]\\%(in \\| from\\)\\)\\?\\(\\%([0-9]*[^0-9\\n]\\)\\%([^\\n :]\\| [^-/\\n]\\|:[^ \\n]\\)\\{-}\\)\\%(: \\?\\)\\([0-9]\\+\\)\\%(-\\([0-9]\\+\\)\\%(\\.\\([0-9]\\+\\)\\)\\?\\|[.:]\\([0-9]\\+\\)\\%(-\\%(\\([0-9]\\+\\)\\.\\)\\([0-9]\\+\\)\\)\\?\\)\\?:\\%( *\\(\\%(FutureWarning\\|RuntimeWarning\\|W\\%(arning\\)\\|warning\\)\\)\\| *\\([Ii]nfo\\%(\\>\\|formationa\\?l\\?\\)\\|I:\\|\\[ skipping .\\+ ]\\|instantiated from\\|required from\\|[Nn]ote\\)\\| *\\%([Ee]rror\\)\\|\\%([0-9]\\?\\)\\%([^0-9\\n]\\|$\\)\\|[0-9][0-9][0-9]\\)",
		filename = 1,
		row = { 2, 3 },
		col = { 5, 4 },
		type = { 8, 9 },
	},
	lcc = {
		regex = "^\\%(E\\|\\(W\\)\\), \\([^(\n]\\+\\)(\\([0-9]\\+\\),[ \t]*\\([0-9]\\+\\)",
		filename = 2,
		row = 3,
		col = 4,
		type = { 1 },
	},
	makepp = {
		regex = "^makepp\\%(\\%(: warning\\(:\\).\\{-}\\|\\(: Scanning\\|: [LR]e\\?l\\?oading makefile\\|: Imported\\|log:.\\{-}\\) \\|: .\\{-}\\)`\\(\\(\\S \\{-1,}\\)\\%(:\\([0-9]\\+\\)\\)\\?\\)['(]\\)",
		filename = 4,
		row = 5,
		type = { 1, 2 },
	},
	mips_1 = {
		regex = " (\\([0-9]\\+\\)) in \\([^ \n]\\+\\)",
		filename = 2,
		row = 1,
	},
	mips_2 = {
		regex = " in \\([^()\n ]\\+\\)(\\([0-9]\\+\\))$",
		filename = 1,
		row = 2,
	},
	omake = {
		regex = "^\\*\\*\\* omake: file \\(.*\\) changed",
		filename = 1,
	},
	oracle = {
		regex = "^\\%(Semantic error\\|Error\\|PCC-[0-9]\\+:\\).* line \\([0-9]\\+\\)\\%(\\%(,\\| at\\)\\? column \\([0-9]\\+\\)\\)\\?\\%(,\\| in\\| of\\)\\? file \\(.\\{-}\\):\\?$",
		filename = 3,
		row = 1,
		col = 2,
	},
	perl = {
		regex = " at \\([^ \n]\\+\\) line \\([0-9]\\+\\)\\%([,.]\\|$\\| during global destruction\\.$\\)",
		filename = 1,
		row = 2,
	},
	php = {
		regex = "\\%(Parse\\|Fatal\\) error: \\(.*\\) in \\(.*\\) on line \\([0-9]\\+\\)",
		filename = 2,
		row = 3,
	},
	-- TODO: support multi-line errors
	rxp = {
		regex = "^\\%(Error\\|Warnin\\(g\\)\\):.*\n.* line \\([0-9]\\+\\) char \\([0-9]\\+\\) of file://\\(.\\+\\)",
		filename = 4,
		row = 2,
		col = 3,
		type = { 1 },
	},
	sun = {
		regex = ": \\%(ERROR\\|WARNIN\\(G\\)\\|REMAR\\(K\\)\\) \\%([[:alnum:] ]\\+, \\)\\?File = \\(.\\+\\), Line = \\([0-9]\\+\\)\\%(, Column = \\([0-9]\\+\\)\\)\\?",
		filename = 3,
		row = 4,
		col = 5,
		type = { 1, 2 },
	},
	sun_ada = {
		regex = "^\\([^, \n\t]\\+\\), line \\([0-9]\\+\\), char \\([0-9]\\+\\)[:., (-]",
		filename = 1,
		row = 2,
		col = 3,
	},
	watcom = {
		regex = "^[ \t]*\\(\\%([a-zA-Z]:\\)\\?[^ :(\t\n][^:(\t\n]*\\)(\\([0-9]\\+\\)): \\?\\%(\\(Error! E[0-9]\\+\\)\\|\\(Warning! W[0-9]\\+\\)\\):",
		filename = 1,
		row = 2,
		type = { 4 },
	},
	["4bsd"] = {
		regex = "\\%(^\\|::  \\|\\S ( \\)\\(/[^ \n\t()]\\+\\)(\\([0-9]\\+\\))\\%(: \\(warning:\\)\\?\\|$\\| ),\\)",
		filename = 1,
		row = 2,
		type = { 3 },
	},
	["perl__Pod::Checker"] = {
		regex = "^\\*\\*\\* \\%(ERROR\\|\\(WARNING\\)\\).* \\%(at\\|on\\) line \\([0-9]\\+\\) \\%(.* \\)\\?in file \\([^ \t\n]\\+\\)",
		filename = 3,
		row = 2,
		type = { 1 },
	},
}

---Given a `matchlistpos` result and a capture-group matcher, return the location of the relevant capture group(s).
---
---@param result (CompileModeRange|nil)[]
---@param group integer|CompileModeIntByInt|nil
---@return CompileModeRange|nil
---@return CompileModeRange|nil
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

---Get the range and its value from a certain line
---@param line string
---@param range CompileModeRange
---@return CompileModeValueAndRange<string>
local function range_and_value(line, range)
	return {
		value = line:sub(range.start, range.end_),
		range = range,
	}
end

---Get the range and its numeric value, if it contains a number.
---@param line string
---@param range CompileModeRange|nil
---@return CompileModeValueAndRange<number>|nil
local function numeric_range_and_value(line, range)
	if not range then
		return nil
	end

	local raw = range_and_value(line, range)
	local parsed = tonumber(raw.value)
	if not parsed then
		return nil
	end
	return { value = parsed, range = raw.range }
end

---Parse a line for errors using a specific matcher from `error_regexp_table`.
---@param matcher CompileModeRegexpMatcher|nil
---@param line string
---@param linenum integer
---@return CompileModeError|nil
local function parse_matcher(matcher, line, linenum)
	if not matcher then
		return nil
	end

	matcher._rx = matcher._rx or vim.regex(matcher.regex)

	local regex = matcher.regex
	local result = utils.matchlistpos(line, matcher.regex, matcher._rx)
	if not result then
		return nil
	end

	local filename_range = result[matcher.filename + 1]
	if not filename_range then
		return nil
	end

	local row_range, end_row_range = parse_matcher_group(result, matcher.row)
	local col_range, end_col_range = parse_matcher_group(result, matcher.col)

	---@type CompileModeLevel
	local error_level
	local matcher_type = matcher.type
	if matcher_type == nil then
		error_level = M.level.ERROR
	elseif type(matcher_type) == "number" then
		error_level = matcher_type
	elseif type(matcher_type) == "table" then
		if result[matcher_type[1] + 1] then
			error_level = M.level.WARNING
		elseif matcher_type[2] and result[matcher_type[2] + 1] then
			error_level = M.level.INFO
		else
			error_level = M.level.ERROR
		end
	end

	---@type CompileModeError
	return {
		highlighted = false,
		level = error_level,
		priority = matcher.priority or 1,
		full = result[1],
		full_text = line,
		filename = range_and_value(line, filename_range),
		row = numeric_range_and_value(line, row_range),
		col = numeric_range_and_value(line, col_range),
		end_row = numeric_range_and_value(line, end_row_range),
		end_col = numeric_range_and_value(line, end_col_range),
		group = nil,
		linenum = linenum,
	}
end

---@param error CompileModeError
---@return unknown
local function map_to_qflist(error)
	return {
		filename = error.filename.value,
		lnum = error.row and error.row.value,
		end_lnum = error.end_row and error.end_row.value,
		col = error.col and error.col.value,
		end_col = error.end_col and error.end_col.value,
		text = error.full_text,
	}
end

---@param error_list table<integer, CompileModeError> table of compilation errors, usually `errors.error_list`
---@return unknown[] qflist values which can be inserted into the quickfix list using `setqflist()`
function M.toqflist(error_list)
	return vim.tbl_values(vim.tbl_map(map_to_qflist, error_list))
end

---@param bufnr integer
---@param error CompileModeError
---@return vim.Diagnostic
local function map_to_diagnostic(bufnr, error)
	---@type vim.diagnostic.Severity
	local level
	if error.level == M.level.ERROR then
		level = vim.diagnostic.severity.ERROR
	elseif error.level == M.level.WARNING then
		level = vim.diagnostic.severity.ERROR
	else
		level = vim.diagnostic.severity.INFO
	end

	---@type vim.Diagnostic
	return {
		bufnr = bufnr,
		col = error.col and error.col.value - 1 or 0,
		lnum = error.row.value - 1,
		message = error.full_text,
		severity = level,
		end_col = error.end_col and error.end_col.value - 1,
		end_lnum = error.end_row and error.end_row.value - 1,
	}
end

---@param error_list table<integer, CompileModeError> table of compilation errors, usually `errors.error_list`
---@return vim.Diagnostic[]
function M.todiagnostic(bufnr, error_list)
	return vim.iter(vim.tbl_values(error_list))
		:filter(function(error)
			local error_buf = vim.fn.bufadd(error.filename.value)
			return error_buf == bufnr
		end)
		:map(function(error)
			return map_to_diagnostic(bufnr, error)
		end)
		:totable()
end

local _cached_config = nil
local function get_config()
	if _cached_config then
		return _cached_config
	end
	_cached_config = require("compile-mode.config.internal")
	return _cached_config
end

local _ordered = nil
local function get_ordered()
	if _ordered then
		return _ordered
	end

	local config = get_config()
	_ordered = {}
	for group, matcher in pairs(config.error_regexp_table) do
		---@cast matcher CompileModeRegexpMatcher
		table.insert(_ordered, { group = group, matcher = matcher })
	end

	table.sort(_ordered, function(a, b)
		local pa = a.matcher.priority or 0
		local pb = b.matcher.priority or 0
		if pa ~= pb then
			return pa > pb
		end
		return tostring(a.group) < tostring(b.group)
	end)

	return _ordered
end

---Parses error syntax from a given line.
---@param line string the line to parse
---@param linenum integer the line number of the parsed line
---@return CompileModeError|nil
function M.parse(line, linenum)
	local config = get_config()

	local ordered = get_ordered()
	for _, item in ipairs(ordered) do
		local result = parse_matcher(item.matcher, line, linenum)
		if result then
			result.group = item.group

			local ignored = false
			for _, pattern in ipairs(config.error_ignore_file_list or {}) do
				if vim.fn.match(result.filename.value, pattern) ~= -1 then
					ignored = true
					break
				end
			end

			if not ignored then
				return result
			end
		end
	end

	return nil
end

---Highlight a single error in the compilation buffer.
---@param bufnr integer
---@param error CompileModeError
---@param linenum integer
local function highlight_error(bufnr, error, linenum)
	if error.highlighted then
		return
	end

	error.highlighted = true

	local full_range = error.full
	utils.add_highlight(bufnr, "CompileModeMessage", linenum, full_range)

	local hlgroup = "CompileMode"
	if error.level == M.level.WARNING then
		hlgroup = hlgroup .. "Warning"
	elseif error.level == M.level.INFO then
		hlgroup = hlgroup .. "Info"
	else
		hlgroup = hlgroup .. "Error"
	end

	local filename_range = error.filename.range
	utils.add_highlight(bufnr, hlgroup, linenum, filename_range)

	local row_range = error.row and error.row.range
	if row_range then
		utils.add_highlight(bufnr, "CompileModeMessageRow", linenum, row_range)
	end
	local end_row_range = error.end_row and error.end_row.range
	if end_row_range then
		utils.add_highlight(bufnr, "CompileModeMessageRow", linenum, end_row_range)
	end

	local col_range = error.col and error.col.range
	if col_range then
		utils.add_highlight(bufnr, "CompileModeMessageCol", linenum, col_range)
	end
	local end_col_range = error.end_col and error.end_col.range
	if end_col_range then
		utils.add_highlight(bufnr, "CompileModeMessageCol", linenum, end_col_range)
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
