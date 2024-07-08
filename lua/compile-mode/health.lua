local health = {}

function health.check()
	local all_ok = true
	vim.health.start("compile-mode.nvim report")

	local config = require("compile-mode.config.internal")

	---@diagnostic disable-next-line: undefined-field
	vim.iter(config.health_info.unrecognized_keys)
		:map(function(key)
			all_ok = false
			return "found unrecognized option: " .. key
		end)
		:each(vim.health.warn)

	local config_ok, err = require("compile-mode.config.check").validate(config)
	if not config_ok then
		all_ok = false
		vim.health.error(err or "")
	end

	local baleia_ok = pcall(require, "baleia")
	if config.baleia_setup ~= false and not baleia_ok then
		all_ok = false
		vim.health.error("configured baleia_setup but failed to require baleia")
	end

	if all_ok then
		vim.health.ok("everything checks out")
	end
end

return health
