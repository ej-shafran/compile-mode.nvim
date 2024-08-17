local helpers = require("spec.test_helpers")

local function env_variable(var)
	if vim.o.shell:match("cmd.exe$") then
		return "echo %" .. var .. "%"
	elseif vim.o.shell:match("pwdh$") or vim.o.shell:match("powershell$") then
		return "echo $Env:" .. var
	else
		return "echo $" .. var
	end
end

local function invalid_env_value(var)
	-- For `cmd`, an invalid environment variable results in that variable's string
	-- whereas for `*sh` shells, it results in an empty string

	if vim.o.shell:match("cmd.exe$") then
		return "%" .. var .. "%"
	else
		return ""
	end
end

local assert = require("luassert")

describe("`environment` option", function()
	local environment = { TESTING = "some value" }

	before_each(function()
		helpers.setup_tests({ environment = environment })
	end)

	it("should set an environment variable for commands", function()
		local cmd = env_variable("TESTING")

		helpers.compile({ args = cmd })

		assert.are.same({ cmd, environment.TESTING }, helpers.get_output())
	end)

	it("should not override existing environment variables", function()
		local cmd = env_variable("OTHER")
		vim.env.OTHER = "some value"

		helpers.compile({ args = cmd })

		assert.are.same({ cmd, vim.env.OTHER }, helpers.get_output())
	end)
end)

describe("`clear_environment` option", function()
	it("should override existing environment variables", function()
		helpers.setup_tests({ clear_environment = true })

		local cmd = env_variable("OTHER")
		vim.env.OTHER = "some value"

		helpers.compile({ args = cmd })

		assert.are.same({ cmd, invalid_env_value("OTHER") }, helpers.get_output())
	end)
end)
