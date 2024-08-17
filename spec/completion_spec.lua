local helpers = require("spec.test_helpers")

describe(":Compile completion", function()
	before_each(helpers.setup_tests)

	it("should complete executables", function()
		local results = vim.fn.getcompletion("Compile ", "cmdline")
		for _, result in pairs(results) do
			local is_executable = vim.fn.executable(result) == 1
			local is_file = vim.uv.fs_stat(result) ~= nil
			assert.is_true(is_executable or is_file, ("%s is not an executable or file"):format(result))
		end
	end)

	it("should complete files for executables", function()
		local results = vim.fn.getcompletion("Compile cat ", "cmdline")
		for _, result in pairs(results) do
			local is_file = vim.uv.fs_stat(result) ~= nil
			assert.is_true(is_file, ("%s is not a file"):format(result))
		end
	end)
end)
