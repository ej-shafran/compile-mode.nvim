local errors = require("compile-mode.errors")
local log = require("compile-mode.log")

local ok = pcall(require, "telescope")

if not ok then
	log.warn('could not require "telescope"')
	return
end

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local entry_display = require("telescope.pickers.entry_display")

local displayer = entry_display.create({
	separator = " ",
	items = {
		{ width = 1 },
		{ remaining = true },
	},
})

---@param error CompileModeError
local function make_display(error)
	local level
	if error.level == errors.level.ERROR then
		level = { "E", "CompileModeError" }
	elseif error.level == errors.level.WARNING then
		level = { "W", "CompileModeWarning" }
	else
		level = { "I", "CompileModeInfo" }
	end

	return function()
		return displayer({
			level,
			error.full_text,
		})
	end
end

---@param error CompileModeError
---@return table
local function entry_maker(error)
	return {
		value = error,
		ordinal = error.linenum,
		filename = error.filename.value,
		lnum = error.row and error.row.value,
		col = error.col and error.col.value,
		display = make_display(error),
	}
end

return function(opts)
	opts = opts or {}

	pickers
		.new(opts, {
			prompt_title = "Compilation Errors",
			finder = finders.new_table({
				results = vim.iter(pairs(errors.error_list))
					:map(function(_, v)
						return v
					end)
					:totable(),
				entry_maker = opts.entry_maker or entry_maker,
			}),
			previewer = conf.grep_previewer(opts),
			sorter = conf.generic_sorter(opts),
		})
		:find()
end
