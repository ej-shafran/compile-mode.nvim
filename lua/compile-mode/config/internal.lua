local compile_mode = require("compile-mode")
local check = require("compile-mode.config.check")
local log = require("compile-mode.log")

---@class CompileModeConfig
local default_config = {
	---@type string
	buffer_name = "*compilation*",
	---@type string
	time_format = "%a %b %e %H:%M:%S",
	---@type string
	default_command = "make -k ",

	---@type table<string, CompileModeRegexpMatcher>
	error_regexp_table = {},
	---@type string[]
	error_ignore_file_list = {},
	---@type CompileModeLevel
	error_threshold = compile_mode.level.WARNING,

	---@type boolean
	use_diagnostics = false,

	---@type string[]
	hidden_output = {},

	---@type boolean
	ask_about_save = true,
	---@type boolean
	ask_to_interrupt = true,
	---@type boolean
	recompile_no_fail = false,
	---@type boolean
	auto_jump_to_first_error = false,
	---@type boolean|number|nil
	error_locus_highlight = 500,

	---@type table<string, string>|nil
	environment = nil,
	---@type boolean
	clear_environment = false,

	---@type table | boolean
	baleia_setup = false,
	---@type boolean
	bang_expansion = false,
	---@type boolean
	input_word_completion = false,

	---@type boolean
	debug = false,

	--- @type boolean
	hidden_buffer = false,

	--- @type boolean
	focus_compilation_buffer = false,
}

local user_config = type(vim.g.compile_mode) == "function" and vim.g.compile_mode() or vim.g.compile_mode

local health_info = {
	health_info = {
		unrecognized_keys = check.unrecognized_keys(user_config or {}, default_config),
		no_user_config = user_config == nil,
	},
}

local config = vim.tbl_extend("force", health_info, default_config, user_config or {})
config.error_regexp_table =
	vim.tbl_extend("force", require("compile-mode.errors").error_regexp_table, config.error_regexp_table)
config.error_ignore_file_list = vim.list_extend({ "/bin/[a-z]*sh$" }, config.error_ignore_file_list)
config.hidden_output = type(config.hidden_output) == "string" and { config.hidden_output } or config.hidden_output

local ok, err = check.validate(config)
if not ok then
	log.error(err)
end

if #config.health_info.unrecognized_keys > 0 then
	log.fmt_warn("found unrecognized options: %s", config.health_info.unrecognized_keys)
end

if config.health_info.no_user_config then
	log.warn("no configuration found; did you forget to set the `vim.g.compile_mode` table?")
end

---@cast config CompileModeConfig

--- Modify the log level based off the parsed config
log.new({ level = config.debug and "debug" or "info" }, true)

return config
