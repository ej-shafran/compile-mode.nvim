local health = {}

function health.check()
	local all_ok = true

	vim.health.start("compile-mode.nvim version")
	local file = vim.api.nvim_get_runtime_file("lua/compile-mode/init.lua", false)[1]
	if not file then
		vim.health.error("could not find compile-mode module in runtimepath")
	else
		local compile_mode_repo = vim.fs.dirname(file)
		local version = vim.system({ "git", "describe" }, { cwd = compile_mode_repo }):wait()
		if version.code ~= 0 then
			vim.health.error(("failed to get git information:\n%s"):format(version.stderr))
		else
			vim.health.info(vim.fn.trim(version.stdout))
		end
	end

	vim.health.start("compile-mode.nvim report")

	local config = require("compile-mode.config.internal")

	---@diagnostic disable-next-line: undefined-field
	if config.health_info.no_user_config then
		all_ok = false
		vim.health.warn("no configuration found; did you forget to set the `vim.g.compile_mode` table?")
	end

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
