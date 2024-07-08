local check = {}

---@param tbl table the table to validate
---@see vim.validate
---@return boolean is_valid
---@return string error_message
local function validate(tbl)
	local ok, err = pcall(vim.validate, tbl)
	return ok or false, "invalid config" .. (err and (": " .. err) or "")
end

local function validate_string_list(value)
	return {
		value,
		function(lst)
			return type(lst) == "table" and vim.iter(lst):all(function(str)
				return type(str) == "string"
			end)
		end,
		"list of strings",
	}
end

local function validate_regex(value)
	return {
		value,
		function(str)
			if type(str) ~= "string" then
				return false
			end

			local ok = pcall(vim.regex, str)
			return ok
		end,
		"regex",
	}
end

local function validate_error_regexp_table(value)
	return {
		value,
		function(regexp_table)
			if type(regexp_table) ~= "table" then
				return false
			end

			---@type string|nil
			local err_msg = nil
			local ok = vim.iter(regexp_table):all(function(group, matcher)
				if matcher == false then
					return true
				end

				if type(matcher) ~= "table" then
					err_msg = group .. " expected table or false, got " .. type(matcher)
					return false
				end

				local ok, err = pcall(vim.validate, {
					regex = validate_regex(matcher.regex),
					filename = { matcher.filename, "number" },
					row = { matcher.row, { "number", "table" }, true },
					col = { matcher.col, { "number", "table" }, true },
					type = { matcher.type, { "number", "table" }, true },
				})
				if not ok then
					err_msg = group .. "." .. err
				end
				return ok
			end)

			return ok, err_msg
		end,
		"error regex matcher table",
	}
end

---@param cfg CompileModeConfig
---@return boolean is_valid
---@return string error_message
function check.validate(cfg)
	return validate({
		buffer_name = { cfg.buffer_name, "string" },
		time_format = { cfg.time_format, "string" },
		default_command = { cfg.default_command, "string" },
		ask_about_save = { cfg.ask_about_save, "boolean" },
		ask_to_interrupt = { cfg.ask_to_interrupt, "boolean" },
		recompile_no_fail = { cfg.recompile_no_fail, "boolean" },
		same_window_errors = { cfg.same_window_errors, "boolean" },
		auto_jump_to_first_error = { cfg.auto_jump_to_first_error, "boolean" },
		environment = { cfg.environment, "table", true },
		clear_environment = { cfg.clear_environment, "boolean" },
		baleia_setup = { cfg.baleia_setup, { "boolean", "table" } },
		debug = { cfg.debug, "boolean" },
		error_ignore_file_list = validate_string_list(cfg.error_ignore_file_list),
		hidden_output = validate_string_list(cfg.hidden_output),
		error_regexp_table = validate_error_regexp_table(cfg.error_regexp_table),
	})
end

---Recursively check a table for unrecognized keys,
---using a default table as a reference
---@param tbl table
---@param default_tbl table
---@return string[]
function check.unrecognized_keys(tbl, default_tbl)
	local keys = {}
	for k, _ in pairs(tbl) do
		if k ~= "error_regexp_table" then
			keys[k] = true
		end
	end
	for k, _ in pairs(default_tbl) do
		if k ~= "error_regexp_table" then
			keys[k] = false
		end
	end
	local ret = {}
	for k, _ in pairs(keys) do
		if keys[k] then
			table.insert(ret, k)
		end
		if type(default_tbl[k]) == "table" and type(tbl[k]) == "table" then
			for _, subk in pairs(check.unrecognized_keys(tbl[k], default_tbl[k])) do
				local key = k .. "." .. subk
				table.insert(ret, key)
			end
		end
	end
	return ret
end

return check
