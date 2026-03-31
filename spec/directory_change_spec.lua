local helpers = require("spec.test_helpers")

describe("default directory_change_matchers", function()
	before_each(helpers.setup_tests)

	it("should match `cd` lines", function()
		local expected = { filename = "directory_change_makefile", row = 1, col = 1 }

		helpers.compile({
			args = "cd spec && echo " .. helpers.quote_for_echo(helpers.sun_ada_error(expected)),
		})
		helpers.next_error()
		helpers.assert_at_error_locus(expected)
	end)

	it("should match `Entering directory` lines", function()
		local expected = { filename = "directory_change_makefile", row = 1, col = 1 }

		helpers.compile({ args = "make -w -C spec -f directory_change_makefile error" })
		helpers.next_error()
		helpers.assert_at_error_locus(expected)
	end)
end)

describe("custom directory_change_matchers", function()
	before_each(function()
		helpers.setup_tests({
			directory_change_matchers = {
				{ regex = [[@\(\S\+\)\( !\)\?$]], filename = 1, leaving = 2 },
			},
		})
	end)

	it("should work for entering a directory", function()
		local expected = { filename = "directory_change_makefile", row = 1, col = 1 }

		helpers.compile({ args = "echo @spec&& echo " .. helpers.quote_for_echo(helpers.sun_ada_error(expected)) })
		helpers.next_error()
		helpers.assert_at_error_locus(expected)
	end)

	it("should work for leaving a directory", function()
		local expected = { filename = "README.md", row = 1, col = 1 }

		helpers.compile({
			args = "echo @spec&& echo @spec !&& echo " .. helpers.quote_for_echo(helpers.sun_ada_error(expected)),
		})
		helpers.next_error()
		helpers.assert_at_error_locus(expected)
	end)
end)
