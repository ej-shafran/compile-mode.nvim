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

	if config.baleia_setup ~= nil and config.baleia_setup ~= false then
		all_ok = false
		if config.baleia_setup == true then
			vim.health.warn(
				[['baleia_setup' at top level is deprecated;]]
					.. [[ use 'ansi_color = { kind = "render" }' instead.]]
					.. [[ It will be removed in v6.]]
			)
		else
			vim.health.warn(
				[['baleia_setup' at top level is deprecated;]]
					.. [[ use 'ansi_color = { kind = "render", baleia_options = ]]
					.. vim.inspect(config.baleia_setup, { newline = "" })
					.. [[ }' instead.]]
					.. [[ It will be removed in v6.]]
			)
		end
	end

	---@diagnostic disable-next-line: undefined-field
	vim.iter(config.health_info.unrecognized_keys)
		:map(function(key)
			all_ok = false
			return "found unrecognized option: " .. key
		end)
		:each(vim.health.warn)

	local errors = require("compile-mode.config.check").get_errors(config)
	if #errors > 0 then
		all_ok = false

		vim.iter(errors):each(vim.health.warn)
	end

	if config.ansi_color.kind == "render" then
		local baleia_ok = pcall(require, "baleia")
		if not baleia_ok then
			all_ok = false
			vim.health.warn(
				"ansi_color.kind is set to 'render' but failed to require baleia.nvim."
					.. "ANSI colors will be filtered instead of rendered."
			)
		end
	end

	if all_ok then
		vim.health.ok("everything checks out")
	end
end

return health
