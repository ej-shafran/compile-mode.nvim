## Introduction

`compile-mode.nvim` is a Neovim plugin which emulates the features of Emacs' `Compilation Mode`. It allows you to run commands which are output into a special buffer, and then rerun that command over and over again as much as you need. See [Emacs Compilation Mode](https://www.gnu.org/software/emacs/manual/html_node/emacs/Compilation-Mode.html) for more details.

## Installation

Use your favorite plugin manager. `compile-mode.nvim` depends on [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) and on [baleia.nvim](https://github.com/m00qek/baleia.nvim) (unless the [`no_baleia_support`](#no_baleia_support) option is set).

Here's an example of a [Lazy](https://github.com/folke/lazy.nvim) config for `compile-mode.nvim`:

```lua
return {
  "ej-shafran/compile-mode.nvim",
  branch = "latest",
  -- or a specific version:
  -- tag = "v2.0.0"
  dependencies = {
    "nvim-lua/plenary.nvim",
    { "m00qek/baleia.nvim", tag = "v1.3.0" },
  },
  opts = {
    -- you can disable colors by uncommenting this line
    -- no_baleia_support = true,
    default_command = "npm run build"
  }
}
```

## Compilation buffer

The compilation buffer is the buffer into which the output of compilation commands is placed. By default, its name is `"*compilation*"` (though this can be configured using the [`buffer_name`](#buffer_name) option). Its filetype is `compilation` - this can be used to setup `:h autocmd`s (and thus custom keymaps and the like).

After a command has been run, the buffer's output will contain:

- the "default directory" - i.e., the current working directory from which the command was run
- the time at which compilation started
- the compilation command which was executed
- the output (`stdout` and `stderr`) of the command
- the exit status of the command (a command can exit successfully, abnormally, or by interruption) and when it occurred

If a compilation command is running and another one is triggered, the first command is terminated (using `:h jobstop`) and this interruption is reported in the compilation buffer. Then, after a tiny delay, the compilation buffer is cleared and the new command starts running.

## Errors

The compilation buffer is checked for errors in real-time, which can then be navigated between using [`CompileGotoError`](#compilegotoerror), [`NextError`](#nexterror) and [`PrevError`](#preverror).

<!-- panvimdoc-include-comment
```vimdoc
					       *compile-mode.error_regexp_table*
```
-->

Errors are defined using the `error_regexp_table` option. Each field in the table consists of a key (the name of the error's source, used for debug information) and a table value. This table has the following keys:

- {regex} (string) a Vim regex which captures the error and the relevant capture groups; if this regex matches a line an error is determined to be on that line
- {filename} (integer) the capture group number for the error's filename (capture groups start at 1)
- {row} (integer|[integer, integer]) either the capture group for the row on which the error occurred, or capture groups for the start and end of the row range in which the error occurred (optional)
- {col} (integer|[integer, integer]) either the capture group for the column on which the error occurred, or the capture groups for the start and end of the column range in which the error occurred (optional)
- {type} (level|[integer,integer?]) either an error type (`INFO`, `WARNING`, or `ERROR`, taken from `require("compile-mode").level`) or a tuple of capture groups (optional, default `ERROR`)
  - If capture groups are provided and the first capture group is matched, the error is considered of type `WARNING`. If the second capture group matched, the error is considered to be of type `INFO`.

**Note:** a type alias - `RegexpMatcher` - is available for the values of `error_regexp_table`

For example, to add TypeScript errors:

```lua
require("compile-mode").setup({
    error_regexp_table = {
      typescript = {
	-- TypeScript errors take the form
	-- "path/to/error-file.ts(13,23): error TS22: etc."
        regex = "^\\(.\\+\\)(\\([1-9][0-9]*\\),\\([1-9][0-9]*\\)): error TS[1-9][0-9]*:",
        filename = 1,
        row = 2,
        col = 3,
      }
    }
})
```

<!-- panvimdoc-ignore-start -->
<details>

<summary>
<!-- panvimdoc-ignore-end -->
The default for `error_regexp_table` is:
<!-- panvimdoc-ignore-start -->
</summary>
<!-- panvimdoc-ignore-end -->

```lua
error_regexp_table = {
	absoft = {
		regex = '^\\%([Ee]rror on \\|[Ww]arning on\\( \\)\\)\\?[Ll]ine[ 	]\\+\\([0-9]\\+\\)[ 	]\\+of[ 	]\\+"\\?\\([a-zA-Z]\\?:\\?[^":\n]\\+\\)"\\?:',
		filename = 3,
		row = 2,
		type = { 1 },
	},
	ada = {
		regex = "\\(warning: .*\\)\\? at \\([^ \n]\\+\\):\\([0-9]\\+\\)$",
		filename = 2,
		row = 3,
		type = { 1 },
	},
	aix = {
		regex = " in line \\([0-9]\\+\\) of file \\([^ \n]\\+[^. \n]\\)\\.\\? ",
		filename = 2,
		row = 1,
	},
	ant = {
		regex = "^[ 	]*\\%(\\[[^] \n]\\+\\][ 	]*\\)\\{1,2\\}\\(\\%([A-Za-z]:\\)\\?[^: \n]\\+\\):\\([0-9]\\+\\):\\%(\\([0-9]\\+\\):\\([0-9]\\+\\):\\([0-9]\\+\\):\\)\\?\\( warning\\)\\?",
		filename = 1,
		row = { 2, 4 },
		col = { 3, 5 },
		type = { 6 },
	},
	bash = {
		regex = "^\\([^: \n	]\\+\\): line \\([0-9]\\+\\):",
		filename = 1,
		row = 2,
	},
	borland = {
		regex = "^\\%(Error\\|Warnin\\(g\\)\\) \\%([FEW][0-9]\\+ \\)\\?\\([a-zA-Z]\\?:\\?[^:( 	\n]\\+\\) \\([0-9]\\+\\)\\%([) 	]\\|:[^0-9\n]\\)",
		filename = 2,
		row = 3,
		type = { 1 },
	},
	python_tracebacks_and_caml = {
		regex = '^[ 	]*File \\("\\?\\)\\([^," \n	<>]\\+\\)\\1, lines\\? \\([0-9]\\+\\)-\\?\\([0-9]\\+\\)\\?\\%($\\|,\\%( characters\\? \\([0-9]\\+\\)-\\?\\([0-9]\\+\\)\\?:\\)\\?\\([ \n]Warning\\%( [0-9]\\+\\)\\?:\\)\\?\\)',
		filename = 2,
		row = { 3, 4 },
		col = { 5, 6 },
		type = { 7 },
	},
	cmake = {
		regex = "^CMake \\%(Error\\|\\(Warning\\)\\) at \\(.*\\):\\([1-9][0-9]*\\) ([^)]\\+):$",
		filename = 2,
		row = 3,
		type = { 1 },
	},
	cmake_info = {
		regex = "^  \\%( \\*\\)\\?\\(.*\\):\\([1-9][0-9]*\\) ([^)]\\+)$",
		filename = 1,
		row = 2,
		type = M.level.INFO,
	},
	comma = {
		regex = '^"\\([^," \n	]\\+\\)", line \\([0-9]\\+\\)\\%([(. pos]\\+\\([0-9]\\+\\))\\?\\)\\?[:.,; (-]\\( warning:\\|[-0-9 ]*(W)\\)\\?',
		filename = 1,
		row = 2,
		col = 3,
		type = { 4 },
	},
	cucumber = {
		regex = "\\%(^cucumber\\%( -p [^[:space:]]\\+\\)\\?\\|#\\)\\%( \\)\\([^(].*\\):\\([1-9][0-9]*\\)",
		filename = 1,
		row = 2,
	},
	msft = {
		regex = "^ *\\([0-9]\\+>\\)\\?\\(\\%([a-zA-Z]:\\)\\?[^ :(	\n][^:(	\n]*\\)(\\([0-9]\\+\\)) \\?: \\%(see declaration\\|\\%(warnin\\(g\\)\\|[a-z ]\\+\\) C[0-9]\\+:\\)",
		filename = 2,
		row = 3,
		type = { 4 },
	},
	edg_1 = {
		regex = "^\\([^ \n]\\+\\)(\\([0-9]\\+\\)): \\%(error\\|warnin\\(g\\)\\|remar\\(k\\)\\)",
		filename = 1,
		row = 2,
		type = { 3, 4 },
	},
	edg_2 = {
		regex = 'at line \\([0-9]\\+\\) of "\\([^ \n]\\+\\)"$',
		filename = 2,
		row = 1,
		type = M.level.INFO,
	},
	epc = {
		regex = "^Error [0-9]\\+ at (\\([0-9]\\+\\):\\([^)\n]\\+\\))",
		filename = 2,
		row = 1,
	},
	ftnchek = {
		regex = "\\(^Warning .*\\)\\? line[ \n]\\([0-9]\\+\\)[ \n]\\%(col \\([0-9]\\+\\)[ \n]\\)\\?file \\([^ :;\n]\\+\\)",
		filename = 4,
		row = 2,
		col = 3,
		type = { 1 },
	},
	gradle_kotlin = {
		regex = "^\\%(\\(w\\)\\|.\\): *\\(\\%([A-Za-z]:\\)\\?[^:\n]\\+\\): *(\\([0-9]\\+\\), *\\([0-9]\\+\\))",
		filename = 2,
		row = 3,
		col = 4,
		type = { 1 },
	},
	iar = {
		regex = '^"\\(.*\\)",\\([0-9]\\+\\)\\s-\\+\\%(Error\\|Warnin\\(g\\)\\)\\[[0-9]\\+\\]:',
		filename = 1,
		row = 2,
		type = { 3 },
	},
	ibm = {
		regex = "^\\([^( \n	]\\+\\)(\\([0-9]\\+\\):\\([0-9]\\+\\)) : \\%(warnin\\(g\\)\\|informationa\\(l\\)\\)\\?",
		filename = 1,
		row = 2,
		col = 3,
		type = { 4, 5 },
	},
	irix = {
		regex = '^[-[:alnum:]_/ ]\\+: \\%(\\%([sS]evere\\|[eE]rror\\|[wW]arnin\\(g\\)\\|[iI]nf\\(o\\)\\)[0-9 ]*: \\)\\?\\([^," \n	]\\+\\)\\%(, line\\|:\\) \\([0-9]\\+\\):',
		filename = 3,
		row = 4,
		type = { 1, 2 },
	},
	java = {
		regex = "^\\%([ 	]\\+at \\|==[0-9]\\+== \\+\\%(at\\|b\\(y\\)\\)\\).\\+(\\([^()\n]\\+\\):\\([0-9]\\+\\))$",
		filename = 2,
		row = 3,
		type = { 1 },
	},
	jikes_file = {
		regex = '^\\%(Found\\|Issued\\) .* compiling "\\(.\\+\\)":$',
		filename = 1,
		type = M.level.INFO,
	},
	maven = {
		regex = "^\\%(\\[\\%(ERROR\\|\\(WARNING\\)\\|\\(INFO\\)\\)] \\)\\?\\([^\n []\\%([^\n :]\\| [^\n/-]\\|:[^\n []\\)*\\):\\[\\([[:digit:]]\\+\\),\\([[:digit:]]\\+\\)] ",
		filename = 3,
		row = 4,
		col = 5,
		type = { 1, 2 },
	},
	clang_include = {
		regex = "^In file included from \\([^\n:]\\+\\):\\([0-9]\\+\\):$",
		filename = 1,
		row = 2,
		type = M.level.INFO,
	},
	gcc_include = {
		regex = "^\\%(In file included \\|                 \\|	\\)from \\([0-9]*[^0-9\n]\\%([^\n :]\\| [^-/\n]\\|:[^ \n]\\)\\{-}\\):\\([0-9]\\+\\)\\%(:\\([0-9]\\+\\)\\)\\?\\%(\\(:\\)\\|\\(,\\|$\\)\\)\\?",
		filename = 1,
		row = 2,
		col = 3,
		type = { 4, 5 },
	},
	["ruby_Test::Unit"] = {
		regex = "^    [[ ]\\?\\([^ (].*\\):\\([1-9][0-9]*\\)\\(\\]\\)\\?:in ",
		filename = 1,
		row = 2,
	},
	gmake = {
		regex = ": \\*\\*\\* \\[\\%(\\(.\\{-1,}\\):\\([0-9]\\+\\): .\\+\\)\\]",
		filename = 1,
		row = 2,
		type = M.level.INFO,
	},
	gnu = {
		regex = "^\\%([[:alpha:]][-[:alnum:].]\\+: \\?\\|[ 	]\\%(in \\| from\\)\\)\\?\\(\\%([0-9]*[^0-9\\n]\\)\\%([^\\n :]\\| [^-/\\n]\\|:[^ \\n]\\)\\{-}\\)\\%(: \\?\\)\\([0-9]\\+\\)\\%(-\\([0-9]\\+\\)\\%(\\.\\([0-9]\\+\\)\\)\\?\\|[.:]\\([0-9]\\+\\)\\%(-\\%(\\([0-9]\\+\\)\\.\\)\\([0-9]\\+\\)\\)\\?\\)\\?:\\%( *\\(\\%(FutureWarning\\|RuntimeWarning\\|W\\%(arning\\)\\|warning\\)\\)\\| *\\([Ii]nfo\\%(\\>\\|formationa\\?l\\?\\)\\|I:\\|\\[ skipping .\\+ ]\\|instantiated from\\|required from\\|[Nn]ote\\)\\| *\\%([Ee]rror\\)\\|\\%([0-9]\\?\\)\\%([^0-9\\n]\\|$\\)\\|[0-9][0-9][0-9]\\)",
		filename = 1,
		row = { 2, 3 },
		col = { 5, 4 },
		type = { 8, 9 },
	},
	lcc = {
		regex = "^\\%(E\\|\\(W\\)\\), \\([^(\n]\\+\\)(\\([0-9]\\+\\),[ 	]*\\([0-9]\\+\\)",
		filename = 2,
		row = 3,
		col = 4,
		type = { 1 },
	},
	makepp = {
		regex = "^makepp\\%(\\%(: warning\\(:\\).\\{-}\\|\\(: Scanning\\|: [LR]e\\?l\\?oading makefile\\|: Imported\\|log:.\\{-}\\) \\|: .\\{-}\\)`\\(\\(\\S \\{-1,}\\)\\%(:\\([0-9]\\+\\)\\)\\?\\)['(]\\)",
		filename = 4,
		row = 5,
		type = { 1, 2 },
	},
	mips_1 = {
		regex = " (\\([0-9]\\+\\)) in \\([^ \n]\\+\\)",
		filename = 2,
		row = 1,
	},
	mips_2 = {
		regex = " in \\([^()\n ]\\+\\)(\\([0-9]\\+\\))$",
		filename = 1,
		row = 2,
	},
	omake = {
		regex = "^\\*\\*\\* omake: file \\(.*\\) changed",
		filename = 1,
	},
	oracle = {
		regex = "^\\%(Semantic error\\|Error\\|PCC-[0-9]\\+:\\).* line \\([0-9]\\+\\)\\%(\\%(,\\| at\\)\\? column \\([0-9]\\+\\)\\)\\?\\%(,\\| in\\| of\\)\\? file \\(.\\{-}\\):\\?$",
		filename = 3,
		row = 1,
		col = 2,
	},
	perl = {
		regex = " at \\([^ \n]\\+\\) line \\([0-9]\\+\\)\\%([,.]\\|$\\| during global destruction\\.$\\)",
		filename = 1,
		row = 2,
	},
	php = {
		regex = "\\%(Parse\\|Fatal\\) error: \\(.*\\) in \\(.*\\) on line \\([0-9]\\+\\)",
		filename = 2,
		row = 3,
	},
	rxp = {
		regex = "^\\%(Error\\|Warnin\\(g\\)\\):.*\n.* line \\([0-9]\\+\\) char \\([0-9]\\+\\) of file://\\(.\\+\\)",
		filename = 4,
		row = 2,
		col = 3,
		type = { 1 },
	},
	sun = {
		regex = ": \\%(ERROR\\|WARNIN\\(G\\)\\|REMAR\\(K\\)\\) \\%([[:alnum:] ]\\+, \\)\\?File = \\(.\\+\\), Line = \\([0-9]\\+\\)\\%(, Column = \\([0-9]\\+\\)\\)\\?",
		filename = 3,
		row = 4,
		col = 5,
		type = { 1, 2 },
	},
	sun_ada = {
		regex = "^\\([^, \n	]\\+\\), line \\([0-9]\\+\\), char \\([0-9]\\+\\)[:., (-]",
		filename = 1,
		row = 2,
		col = 3,
	},
	watcom = {
		regex = "^[ 	]*\\(\\%([a-zA-Z]:\\)\\?[^ :(	\n][^:(	\n]*\\)(\\([0-9]\\+\\)): \\?\\%(\\(Error! E[0-9]\\+\\)\\|\\(Warning! W[0-9]\\+\\)\\):",
		filename = 1,
		row = 2,
		type = { 4 },
	},
	["4bsd"] = {
		regex = "\\%(^\\|::  \\|\\S ( \\)\\(/[^ \n	()]\\+\\)(\\([0-9]\\+\\))\\%(: \\(warning:\\)\\?\\|$\\| ),\\)",
		filename = 1,
		row = 2,
		type = { 3 },
	},
	["perl__Pod::Checker"] = {
		regex = "^\\*\\*\\* \\%(ERROR\\|\\(WARNING\\)\\).* \\%(at\\|on\\) line \\([0-9]\\+\\) \\%(.* \\)\\?in file \\([^ 	\n]\\+\\)",
		filename = 3,
		row = 2,
		type = { 1 },
	},
}
```

<!-- panvimdoc-ignore-start -->
</details>
<!-- panvimdoc-ignore-end -->

## API

<!-- panvimdoc-ignore-start -->

### setup({opts})

<!-- panvimdoc-ignore-end -->
<!-- panvimdoc-include-comment
```vimdoc
compile_mode.setup({opts})	  				  *compile-mode.setup()*
```
-->

Sets up the plugin for use.

Usage:

```lua
require("compile-mode").setup({
    -- you can disable colors by uncommenting this line
    -- no_baleia_support = true,
    default_command = "npm run build",
})
```

Valid keys and values for {opts}:

<!-- panvimdoc-ignore-start -->

#### `error_regexp_table`

See [Errors](#errors).

<!-- panvimdoc-ignore-end -->
<!-- panvimdoc-include-comment
error_regexp_table

See [Errors](#errors).
-->

<!-- panvimdoc-ignore-start -->

#### `no_baleia_support`

By default, `compile-mode.nvim` uses `baleia.nvim` to color in ANSI color escape sequences in the compilation buffer.
You can disable this behavior by setting this config option to `true`.

<!-- panvimdoc-ignore-end -->
<!-- panvimdoc-include-comment
no_baleia_support

: By default, `compile-mode.nvim` uses `baleia.nvim` to color in ANSI color escape sequences in the compilation buffer.
You can disable this behavior by setting this config option to `true`.
-->

<!-- panvimdoc-ignore-start -->

#### `default_command`

The string to show in the `compile()` prompt as a default. You can set it to `""` for an empty prompt.
Defaults to: `"make -k "`.

<!-- panvimdoc-ignore-end -->
<!-- panvimdoc-include-comment
default_command

: The string to show in the |compile-mode.compile()| prompt as a default. You can set it to `""` for an empty prompt.
Defaults to: `"make -k "`.
-->

<!-- panvimdoc-ignore-start -->

#### `time_format`

The way to format the time displayed at the top of the compilation buffer. Passed into `:h strftime()`.
Defaults to: `"%a %b %e %H:%M:%S"`.

<!-- panvimdoc-ignore-end -->
<!-- panvimdoc-include-comment
time_format

: The way to format the time displayed at the top of the compilation buffer. Passed into `:h strftime()`.
Defaults to: `"%a %b %e %H:%M:%S"`.
-->

<!-- panvimdoc-ignore-start -->

#### `baleia_opts`

Table of options to pass into `baleia.setup()`.
Defaults to an empty table.

<!-- panvimdoc-ignore-end -->

<!-- panvimdoc-include-comment
baleia_options

: Table of options to pass into `baleia.setup()`.
Defaults to an empty table
-->

<!-- panvimdoc-ignore-start -->

#### `buffer_name`

The name for the compilation buffer.
Defaults to: `"*compilation*"`.

<!-- panvimdoc-ignore-end -->
<!-- panvimdoc-include-comment
buffer_name

: The name for the compilation buffer.
Defaults to: `"*compilation*"`.
-->

<!-- panvimdoc-ignore-start -->

#### `error_highlights`

A table of highlights to use for errors in the compilation buffer. The possible keys are:

- `{error}` applied to the entire captured error (optional)
- `{error_row}` applied to the number that specifies the row (or range of rows) of the error (optional)
- `{error_col}` applied to the number that specifies the column (or range of columns) of the error (optional)
- `{error_filename}` applied to the filename in which the error ocurred, when the error is of type `ERROR` (optional)
- `{warning_filename}` applied to the filename in which the error ocurred, when the error is of type `WARNING` (optional)
- `{info_filename}` applied to the filename in which the error ocurred, when the error is of type `INFO` (optional)

Each of the values is a table, with the following keys:

- `{background}` (string) sets the `:h guibg` of the highlight group (optional)
- `{foreground}` (string) sets the `:h guifg` of the highlight group (optional)
- `{gui}` (string) sets the `:h highlight-gui` of the highlight group, and can be a comma-seperated list of attributes (optional)

You can use an empty table to remove all styles from a group.

<details>
<summary>
The defaults for `error_highlights` are:
</summary>

```lua
default_highlights = {
	error = {
		gui = "underline",
	},
	error_row = {
		gui = "underline",
		foreground = theme[2],
	},
	error_col = {
		gui = "underline",
		foreground = theme[8],
	},
	error_filename = {
		gui = "bold,underline",
		foreground = theme[9],
	},
	warning_filename = {
		gui = "underline",
		foreground = theme[3],
	},
	info_filename = {
		gui = "underline",
		foreground = theme[14],
	},
}
```

</details>

<!-- panvimdoc-ignore-end -->
<!-- panvimdoc-include-comment
error_highlights

: A table of highlights to use for errors in the compilation buffer. The possible keys are:

- {error} applied to the entire captured error (optional)
- {error_row} applied to the number that specifies the row (or range of rows) of the error (optional)
- {error_col} applied to the number that specifies the column (or range of columns) of the error (optional)
- {error_filename} applied to the filename in which the error ocurred, when the error is of type `ERROR` (optional)
- {warning_filename} applied to the filename in which the error ocurred, when the error is of type `WARNING` (optional)
- {info_filename} applied to the filename in which the error ocurred, when the error is of type `INFO` (optional)

Each of the values is a table, with the following keys:

- {background} (string) sets the `:h guibg` of the highlight group (optional)
- {foreground} (string) sets the `:h guifg` of the highlight group (optional)
- {gui} (string) sets the `:h highlight-gui` of the highlight group, and can be a comma-seperated list of attributes (optional)

You can use an empty table to remove all styles from a group.

The defaults for `error_highlights` are:

```lua
default_highlights = {
	error = {
		gui = "underline",
	},
	error_row = {
		gui = "underline",
		foreground = theme[2],
	},
	error_col = {
		gui = "underline",
		foreground = theme[8],
	},
	error_filename = {
		gui = "bold,underline",
		foreground = theme[9],
	},
	warning_filename = {
		gui = "underline",
		foreground = theme[3],
	},
	info_filename = {
		gui = "underline",
		foreground = theme[14],
	},
}
```
-->

<!-- panvimdoc-ignore-start -->

#### `debug`

Print additional debug information. This is printed using `print`, so you can inspect it with `:h :messages`.

<!-- panvimdoc-ignore-end -->

<!-- panvimdoc-include-comment
debug

: Print additional debug information. This is printed using Lua's print, so you can inspect it with `:h :messages`.
-->

<!-- panvimdoc-ignore-start -->

#### `error_ignore_file_list`

A list of Vim regexes to run each error's filename by, to check if this file should be ignored.

Defaults to: `{ "/bin/[a-z]*sh$" }`. Passing in this option does not override this, but instead extends the list.

<!-- panvimdoc-ignore-end -->

<!-- panvimdoc-include-comment
error_ignore_file_list

: A list of Vim regexes to run each error's filename by, to check if this file should be ignored.

Defaults to: `{ "/bin/[a-z]*sh$" }`. Passing in this option does not override this, but instead extends the list.
-->

<!-- panvimdoc-ignore-start -->

#### `compilation_hidden_output`

A Vim regex or list of Vim regexes run on every line in the compilation buffer which will be substituted with empty strings.

<!-- panvimdoc-ignore-end -->

<!-- panvimdoc-include-comment
compilation_hidden_output

: A Vim regex or list of Vim regexes run on every line in the compilation buffer which will be substituted with empty strings.
-->
<!-- panvimdoc-ignore-start -->

### compile({param})

<!-- panvimdoc-ignore-end -->
<!-- panvimdoc-include-comment
```vimdoc
compile_mode.compile({param})					*compile-mode.compile()*
```
-->

Run a command and place its output in the compilation buffer, reporting on its result.
The command is run from the current working directory.
The compilation buffer is opened in a new split if it isn't already opened.
If {param.args} is not passed in, the user is prompted for a command using `:h vim.ui.input()`.

#### Parameters

- {param} (table) a table, identical to the tables passed into Neovim commands (optional)
  - {param.args}: the string of the command itself, or `nil` if the user should be prompted to enter a command
  - {param.smods}: a table - see the mods field of `:h nvim_parse_cmd()` for more
    - {param.smods.vertical}: makes the window split vertically if the compilation buffer is not yet open
    - {param.smods.silent}: does not print any information
    - {param.smods.split}: modifications for the placement of the split

<!-- panvimdoc-ignore-start -->

### recompile({param})

<!-- panvimdoc-ignore-end -->
<!-- panvimdoc-include-comment
```vimdoc
compile_mode.recompile()					*compile-mode.recompile()*
```
-->

Reruns the last compiled command. See [`:Recompile`](#recompile).

#### Parameters

- {param} (table) a table, identical to the tables passed into Neovim commands (optional)
  - {param.smods}: a table - see the mods field of `:h nvim_parse_cmd()` for more
    - {param.smods.vertical}: makes the window split vertically if the compilation buffer is not yet open
    - {param.smods.silent}: does not print any information
    - {param.smods.split}: modifications for the placement of the split

### next_error()

Jumps to the next error within the compilation buffer. See [`:NextError`](#nexterror).

### prev_error()

Jumps to a prior error within the compilation buffer. See [`:PrevError`](#preverror).

### goto_error()

Jumps to the error under the cursor. See [`:CompileGotoError`](#compilegotoerror).

## Commands

<!-- panvimdoc-ignore-start -->

### `:Compile`

Runs a command and places its output in the compilation buffer.
The command is run from the current working directory.
The compilation buffer is opened in a new split if it isn't already opened.
If an argument is present, it is used as the command. Otherwise, the user is prompted using `:h vim.ui.input()`.

You can run the command using `:h :vert` to split the window vertically. `:h :aboveleft`, `:h :belowright`, `:h :topleft` and `:h :botright` also modify the split.
You can run the command using `:h :silent` to get rid of the "Compilation finished" messages.

<!-- panvimdoc-ignore-end -->
<!-- panvimdoc-include-comment
:Compile
: Runs a command and places its output in the compilation buffer.
The command is run from the current working directory.
The compilation buffer is opened in a new split if it isn't already opened.
If an argument is present, it is used as the command. Otherwise, the user is prompted using `:h vim.ui.input()`.
You can run the command using `:h :vert` to split the window vertically. `:h :aboveleft`, `:h :belowright`, `:h :topleft` and `:h :botright` also modify the split.
You can run the command using `:h :silent` to get rid of the "Compilation finished" messages.

-->

<!-- panvimdoc-ignore-start -->

### `:Recompile`

Reruns the last compiled command. If there isn't one, the error is reported using `:h vim.notify()`.
The compilation buffer is opened in a new split if it isn't already opened.
The command is rerun from the directory in which it was originally run.

You can run the command using `:h :vert` to split the window vertically. `:h :aboveleft`, `:h :belowright`, `:h :topleft` and `:h :botright` also modify the split.
You can run the command using `:h :silent` to get rid of the "Compilation finished" messages.

<!-- panvimdoc-ignore-end -->
<!-- panvimdoc-include-comment
:Recompile

: Reruns the last compiled command. If there isn't one, the error is reported using `:h vim.notify()`.
The compilation buffer is opened in a new split if it isn't already opened.
The command is rerun from the directory in which it was originally run.
You can run the command using `:h :vert` to split the window vertically. `:h :aboveleft`, `:h :belowright`, `:h :topleft` and `:h :botright` also modify the split.
You can run the command using `:h :silent` to get rid of the "Compilation finished" messages.
-->

<!-- panvimdoc-ignore-start -->

### `:NextError`

Jump to the next error in the compilation buffer. This does not take the cursor into effect - it simply starts at the first error in the buffer and continues, one by one, from there. Once the last error in the buffer is reached the command has no effect and reports on this fact.

<!-- panvimdoc-ignore-end -->
<!-- panvimdoc-include-comment
:NextError

: Jump to the next error in the compilation buffer. This does not take the cursor into effect - it simply starts at the first error in the buffer and continues, one by one, from there. Once the last error in the buffer is reached the command has no effect and reports on this fact.
-->

<!-- panvimdoc-ignore-start -->

### `:PrevError`

Jump to a prior error in the compilation buffer. This does not take the cursor into effect - it simply starts at the current error in the buffer and continues backwards, one by one, from there. As long as the current error is before the first error (the default until [`:NextError`](#nexterror) has not yet been used) this command has no effect and reports on this fact.

<!-- panvimdoc-ignore-end -->
<!-- panvimdoc-include-comment
:PrevError

: Jump to a prior error in the compilation buffer. This does not take the cursor into effect - it simply starts at the current error in the buffer and continues backwards, one by one, from there. As long as the current error is before the first error (the default until [`:NextError`](#nexterror) has not yet been used) this command has no effect and reports on this fact.
-->

<!-- panvimdoc-ignore-start -->

### `:CompileGotoError`

Only available within the compilation buffer itself.

Jump to the error present in the line under the cursor. If no such error exists, the command reports on this fact.

<!-- panvimdoc-ignore-end -->
<!-- panvimdoc-include-comment
:CompileGotoError

: Only available within the compilation buffer itself.

Jump to the error present in the line under the cursor. If no such error exists, the command reports on this fact.
-->

<!-- panvimdoc-ignore-start -->

## Contributing

Contributions are welcome in the form of GitHub issues and pull requests.

For contributing details see [[CONTRIBUTING.md]].

<!-- panvimdoc-ignore-end -->
