local utils = require("tests.utils")

---@diagnostic disable-next-line: undefined-global
local describe = describe
---@diagnostic disable-next-line: undefined-global
local it = it
---@type any
local assert = assert

describe("error parsing", function()
	it("should find errors using the default regexes", function()
		utils.setup_tests()

		local filename = "README.md"
		local error_string = "in: " .. filename .. ":1:"

		vim.cmd("silent Compile echo '" .. error_string .. "'")
		utils.wait()

		local filename_length = filename:len()
		local error_length = error_string:len()

		---@type Error
		local expected = {
			full_text = error_string,
			full = {
				start = 1,
				end_ = error_length,
			},
			filename = {
				value = filename,
				range = { start = 5, end_ = 4 + filename_length },
			},
			row = {
				value = 1,
				range = {
					start = error_length - 1,
					end_ = error_length - 1,
				},
			},
			end_row = nil,
			col = nil,
			end_col = nil,
			level = require("compile-mode").level.ERROR,
			highlighted = true,
			group = "gnu",
		}

		-- the error should be on line 5
		assert.are.same(expected, require("compile-mode.errors").error_list[5])
	end)

	it("should use custom regexes", function()
		utils.setup_tests({
			error_regexp_table = {
				typescript = {
					regex = "^\\(.\\+\\)(\\([1-9][0-9]*\\),\\([1-9][0-9]*\\)): error TS[1-9][0-9]*:",
					filename = 1,
					row = 2,
					col = 3,
				},
			},
		})

		local row = 13
		local col = 23
		local filename = "path/to/error-file.ts"
		local error_string = filename .. "(" .. row .. "," .. col .. "): error TS22:"
		local error_length = error_string:len()
		error_string = error_string .. " error details..."

		vim.cmd("silent Compile echo '" .. error_string .. "'")
		utils.wait()

		local filename_length = filename:len()
		local row_length = tostring(row):len()
		local col_length = tostring(col):len()

		---@type Error
		local expected = {
			full_text = error_string,
			full = {
				start = 1,
				end_ = error_length,
			},
			filename = {
				value = filename,
				range = {
					start = 1,
					end_ = filename_length,
				},
			},
			row = {
				value = row,
				range = {
					start = filename_length + 2,
					end_ = filename_length + 1 + row_length,
				},
			},
			end_row = nil,
			col = {
				value = col,
				range = {
					start = filename_length + row_length + 3,
					end_ = filename_length + row_length + 2 + col_length,
				},
			},
			end_col = nil,
			level = require("compile-mode").level.ERROR,
			highlighted = true,
			group = "typescript",
		}

		-- the error should be on line 5
		assert.are.same(expected, require("compile-mode.errors").error_list[5])
	end)
end)
