## Introduction

`compile-mode.nvim` is a Neovim plugin which emulates the features of Emacs'
`Compilation Mode`. It allows you to run commands which are output into a
special buffer, and then rerun that command over and over again as much as you
need. See [Emacs Compilation
Mode](https://www.gnu.org/software/emacs/manual/html_node/emacs/Compilation-Mode.html)
for more details.

## Installation

Use your favorite plugin manager. `compile-mode.nvim` depends on
[plenary.nvim](https://github.com/nvim-lua/plenary.nvim) and on
[baleia.nvim](https://github.com/m00qek/baleia.nvim) (unless the
[`no_baleia_support`](#no_baleia_support) option is set).

Here's an example of a [Lazy](https://github.com/folke/lazy.nvim) config for
`compile-mode.nvim`:

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

The compilation buffer is the buffer into which the output of compilation
commands is placed. By default, its name is `"*compilation*"` (though this can
be configured using the [`buffer_name`](#buffer_name) option). Its filetype is
`compilation` - this can be used to setup `:h autocmd`s (and thus custom keymaps
and the like).

After a command has been run, the buffer's output will contain:

- the "default directory" - i.e., the current working directory from which the
  command was run
- the time at which compilation started
- the compilation command which was executed
- the output (`stdout` and `stderr`) of the command
- the exit status of the command (a command can exit successfully, abnormally,
  or by interruption) and when it occurred

If a compilation command is running and another one is triggered, the first
command is terminated (using `:h jobstop`) and this interruption is reported in
the compilation buffer. Then, after a tiny delay, the compilation buffer is
cleared and the new command starts running.

The compilation buffer has a few local commands and keymaps. The local commands
are [`:CompileGotoError`](#compilegotoerror) and
[`:CompileInterrupt`](#compileinterrupt), mapped to `<CR>` and `<C-c>`
respectively. Additionally, `q` is mapped to `<CMD>q<CR>` to allow for easy
closing of the compilation buffer.

The compilation buffer is deleted automatically when Neovim would be closed, so
unsaved changes don't get in the way. It also has the `:h 'buftype'` option set
to `acwrite`.

## Errors

The compilation buffer is checked for errors in real-time, which can then be
navigated between using [`CompileGotoError`](#compilegotoerror),
[`NextError`](#nexterror) and [`PrevError`](#preverror).

<!-- panvimdoc-include-comment
```vimdoc
					       *compile-mode.error_regexp_table*
```
-->

Errors are defined using the `error_regexp_table` option. Each field in the
table consists of a key (the name of the error's source, used for debug
information) and a table value. This table has the following keys:

<!-- panvimdoc-ignore-start -->

- `{regex}` (string) a Vim regex which captures the error and the relevant
  capture groups; if this regex matches a line an error is determined to be on
  that line
- `{filename}` (integer) the capture group number for the error's filename
  (capture groups start at 1)
- `{row}` (integer|[integer, integer]) either the capture group for the row on
  which the error occurred, or capture groups for the start and end of the row
  range in which the error occurred (optional)
- `{col}` (integer|[integer, integer]) either the capture group for the column
  on which the error occurred, or the capture groups for the start and end of
  the column range in which the error occurred (optional)
- `{type}` (level|[integer,integer?]) either an error type (`INFO`, `WARNING`,
  or `ERROR`, taken from `require("compile-mode").level`) or a tuple of capture
  groups (optional, default `ERROR`)
  - If capture groups are provided and the first capture group is matched, the
    error is considered of type `WARNING`. If the second capture group matched,
    the error is considered to be of type `INFO`.

<!-- panvimdoc-ignore-end -->

<!-- panvimdoc-include-comment
- {regex} (string) a Vim regex which captures the error and the relevant capture
  groups; if this regex matches a line an error is determined to be on that line
- {filename} (integer) the capture group number for the error's filename
  (capture groups start at 1)
- {row} (integer|[integer, integer]) either the capture group for the row on
  which the error occurred, or capture groups for the start and end of the row
  range in which the error occurred (optional)
- {col} (integer|[integer, integer]) either the capture group for the column on
  which the error occurred, or the capture groups for the start and end of the
  column range in which the error occurred (optional)
- {type} (level|[integer,integer?]) either an error type (`INFO`, `WARNING`, or
  `ERROR`, taken from `require("compile-mode").level`) or a tuple of capture
  groups (optional, default `ERROR`)
  - If capture groups are provided and the first capture group is matched, the
    error is considered of type `WARNING`. If the second capture group matched,
    the error is considered to be of type `INFO`. --->

**Note:** a type alias - `RegexpMatcher` - is available for the values of
`error_regexp_table`

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

To see the default for `error_regexp_table`, look at the source code in
`lua/compile-mode/errors.lua` in the plugin's directory (or in the repo itself).

## API

<!-- panvimdoc-ignore-start -->

### setup({opts})

<!-- panvimdoc-ignore-end -->
<!-- panvimdoc-include-comment
```vimdoc
compile_mode.setup({opts})  				  *compile-mode.setup()*
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

By default, `compile-mode.nvim` uses `baleia.nvim` to color in ANSI color escape
sequences in the compilation buffer. You can disable this behavior by setting
this config option to `true`.

<!-- panvimdoc-ignore-end -->
<!-- panvimdoc-include-comment
no_baleia_support

: By default, `compile-mode.nvim` uses `baleia.nvim` to color in ANSI color
escape sequences in the compilation buffer. You can disable this behavior by
setting this config option to `true`.
-->

<!-- panvimdoc-ignore-start -->

#### `default_command`

The string to show in the `compile()` prompt as a default. You can set it to
`""` for an empty prompt. Defaults to: `"make -k "`.

<!-- panvimdoc-ignore-end -->
<!-- panvimdoc-include-comment
default_command

: The string to show in the |compile-mode.compile()| prompt as a default. You
can set it to `""` for an empty prompt. Defaults to: `"make -k "`.
-->

<!-- panvimdoc-ignore-start -->

#### `time_format`

The way to format the time displayed at the top of the compilation buffer.
Passed into `:h strftime()`. Defaults to: `"%a %b %e %H:%M:%S"`.

<!-- panvimdoc-ignore-end -->
<!-- panvimdoc-include-comment
time_format

: The way to format the time displayed at the top of the compilation buffer.
Passed into `:h strftime()`. Defaults to: `"%a %b %e %H:%M:%S"`.
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

A table of highlights to use for errors in the compilation buffer. The possible
keys are:

- `{error}` applied to the entire captured error (optional)
- `{error_row}` applied to the number that specifies the row (or range of rows)
  of the error (optional)
- `{error_col}` applied to the number that specifies the column (or range of
  columns) of the error (optional)
- `{error_filename}` applied to the filename in which the error ocurred, when
  the error is of type `ERROR` (optional)
- `{warning_filename}` applied to the filename in which the error ocurred, when
  the error is of type `WARNING` (optional)
- `{info_filename}` applied to the filename in which the error ocurred, when the
  error is of type `INFO` (optional)

Each of the values is a table, with the following keys:

- `{background}` (string) sets the `:h guibg` of the highlight group (optional)
- `{foreground}` (string) sets the `:h guifg` of the highlight group (optional)
- `{gui}` (string) sets the `:h highlight-gui` of the highlight group, and can
  be a comma-seperated list of attributes (optional)

You can use an empty table to remove all styles from a group.

<details>
<summary>
<code>error_highlights</code> default
</summary>

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

</details>

<!-- panvimdoc-ignore-end -->
<!-- panvimdoc-include-comment
error_highlights

: A table of highlights to use for errors in the compilation buffer. The
possible keys are:

- {error} applied to the entire captured error (optional)
- {error_row} applied to the number that specifies the row (or range of rows) of
  the error (optional)
- {error_col} applied to the number that specifies the column (or range of
  columns) of the error (optional)
- {error_filename} applied to the filename in which the error ocurred, when the
  error is of type `ERROR` (optional)
- {warning_filename} applied to the filename in which the error ocurred, when
  the error is of type `WARNING` (optional)
- {info_filename} applied to the filename in which the error ocurred, when the
  error is of type `INFO` (optional)

Each of the values is a table, with the following keys:

- {background} (string) sets the `:h guibg` of the highlight group (optional)
- {foreground} (string) sets the `:h guifg` of the highlight group (optional)
- {gui} (string) sets the `:h highlight-gui` of the highlight group, and can be
  a comma-seperated list of attributes (optional)

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

Print additional debug information. This is printed using `print`, so you can
inspect it with `:h :messages`.

<!-- panvimdoc-ignore-end -->

<!-- panvimdoc-include-comment
debug

: Print additional debug information. This is printed using Lua's print, so you
can inspect it with `:h :messages`.
-->

<!-- panvimdoc-ignore-start -->

#### `error_ignore_file_list`

A list of Vim regexes to run each error's filename by, to check if this file
should be ignored.

Defaults to: `{ "/bin/[a-z]*sh$" }`. Passing in this option does not override
this, but instead extends the list.

<!-- panvimdoc-ignore-end -->

<!-- panvimdoc-include-comment
error_ignore_file_list

: A list of Vim regexes to run each error's filename by, to check if this file
should be ignored.

Defaults to: `{ "/bin/[a-z]*sh$" }`. Passing in this option does not override
this, but instead extends the list.
-->

<!-- panvimdoc-ignore-start -->

#### `compilation_hidden_output`

A Vim regex or list of Vim regexes run on every line in the compilation buffer
which will be substituted with empty strings.

<!-- panvimdoc-ignore-end -->

<!-- panvimdoc-include-comment
compilation_hidden_output

: A Vim regex or list of Vim regexes run on every line in the compilation buffer
which will be substituted with empty strings.
-->

<!-- panvimdoc-ignore-start -->

#### `recompile_no_fail`

When `true`, running [`:Recompile`](#recompile) without a prior command will not
fail, but instead simply trigger a call to [`:Compile`](#compile).

<!-- panvimdoc-ignore-end -->

<!-- panvimdoc-include-comment
recompile_no_fail

: When `true`, running [`:Recompile`](#recompile) without a prior command will
not fail, but instead simply trigger a call to [`:Compile`](#compile).
-->

<!-- panvimdoc-ignore-start -->

#### `same_window_errors`

By default, going to errors from the compilation buffer uses `:h :wincmd` with
`p` to jump to the error in an existing window, if there is one. You can
override this behavior and override the current window instead by setting this
to `true`.

<!-- panvimdoc-ignore-end -->

<!--panvimdoc-include-comment
same_window_errors

: By default, going to errors from the compilation buffer uses `:h :wincmd` with
`p` to jump to the error in an existing window, if there is one. You can
override this behavior and override the current window instead by setting this
to `true`.
-->

### compile({param})

Run a command and place its output in the compilation buffer, reporting on its
result. See [`:Compile`](#compile).

#### Parameters

<!-- panvimdoc-ignore-start -->

- `{param}` (table) a table, identical to the tables passed into Neovim commands
  (optional)
  - `{param.args}`: the string of the command itself, or `nil` if the user
    should be prompted to enter a command
  - `{param.smods}`: a table - see the mods field of `:h nvim_parse_cmd()` for
  more

<!-- panvimdoc-ignore-end -->

<!-- panvimdoc-include-comment
- {param} (table) a table, identical to the tables passed into Neovim commands
  (optional)
  - {param.args}: the string of the command itself, or `nil` if the user should
    be prompted to enter a command
  - {param.smods}: a table - see the mods field of `:h nvim_parse_cmd()` for
    more
-->

### recompile({param})

Reruns the last compiled command. See [`:Recompile`](#recompile).

#### Parameters

<!-- panvimdoc-ignore-start -->

- `{param}` (table) a table, identical to the tables passed into Neovim commands
  (optional)
  - `{param.smods}`: a table - see the mods field of `:h nvim_parse_cmd()` for
  more

<!-- panvimdoc-ignore-end -->

<!-- panvimdoc-include-comment
- {param} (table) a table, identical to the tables passed into Neovim commands
  (optional)
  - {param.smods}: a table - see the mods field of `:h nvim_parse_cmd()` for
    more
-->

### current_error()

Jumps to the current error within the compilation buffer. See [`:CurrentError`](#currenterror).

### next_error()

Jumps to the next error within the compilation buffer. See [`:NextError`](#nexterror).

### prev_error()

Jumps to a prior error within the compilation buffer. See [`:PrevError`](#preverror).

### goto_error()

Jumps to the error under the cursor. See [`:CompileGotoError`](#compilegotoerror).

### interrupt()

Interrupts the currently running compilation. See [`:CompileInterrupt`](#compileinterrupt).

## Commands

<!-- panvimdoc-ignore-start -->

### `:Compile`

Runs a command and places its output in the compilation buffer. The command is
run from the current working directory. The compilation buffer is opened in a
new split if it isn't already opened. If an argument is present, it is used as
the command. Otherwise, the user is prompted using `:h vim.ui.input()`.

<!-- panvimdoc-ignore-end -->
<!-- panvimdoc-include-comment
:Compile
: Runs a command and places its output in the compilation buffer. The command is
run from the current working directory. The compilation buffer is opened in a
new split if it isn't already opened. If an argument is present, it is used as
the command. Otherwise, the user is prompted using `:h vim.ui.input()`.
-->

The following commands work when prefixed to `:Compile`:

- `:h :vert`
- `:h :aboveleft`, `:h :belowright`, `:h :topleft` and `:h :botright`
- `:h :silent`
- `:h :hide`

Additionally, you can run the command with a `:h count` to set the size of the
opened window, like with `:h :split`.

<!-- panvimdoc-ignore-start -->

### `:Recompile`

Reruns the last compiled command. If there isn't one, the error is reported
using `:h vim.notify()` (unless [`recompile_no_fail`](#recompile_no_fail) is
set). The compilation buffer is opened in a new split if it isn't already
opened. The command is rerun from the directory in which it was originally run.

<!-- panvimdoc-ignore-end -->
<!-- panvimdoc-include-comment
:Recompile

: Reruns the last compiled command. If there isn't one, the error is reported
using `:h vim.notify()`. The compilation buffer is opened in a new split if it
isn't already opened. The command is rerun from the directory in which it was
originally run.
-->

The following commands work when prefixed to `:Compile`:

- `:h :vert`
- `:h :aboveleft`, `:h :belowright`, `:h :topleft` and `:h :botright`
- `:h :silent`
- `:h :hide`

Additionally, you can run the command with a `:h count` to set the size of the
opened window, like with `:h :split`.

<!-- panvimdoc-ignore-start -->

### `:CurrentError`

Jump to the current error in the compilation buffer. This works using the same
cursor that [`:NextError`](#nexterror) and [`:PrevError`](#preverror) operate
on, and acts as a way to jump back to the error you were working after a bit of
iteration and jumping through files. As long as the current error is before the
first error (the default until [`:NextError`](#nexterror) has not yet been used)
this command has no effect and reports on this fact.

<!-- panvimdoc-ignore-end -->

<!-- panvimdoc-include-comment
:CurrentError

: Jump to the current error in the compilation buffer. This works using the same
cursor that [`:NextError`](#nexterror) and [`:PrevError`](#preverror) operate
on, and acts as a way to jump back to the error you were working after a bit of
iteration and jumping through files. As long as the current error is before the
first error (the default until [`:NextError`](#nexterror) has not yet been used)
this command has no effect and reports on this fact.
-->

<!-- panvimdoc-ignore-start -->

### `:NextError`

Jump to the next error in the compilation buffer. This does not take the cursor
into effect - it simply starts at the first error in the buffer and continues,
one by one, from there. Once the last error in the buffer is reached the command
has no effect and reports on this fact.

<!-- panvimdoc-ignore-end -->
<!-- panvimdoc-include-comment
:NextError

: Jump to the next error in the compilation buffer. This does not take the
cursor into effect - it simply starts at the first error in the buffer and
continues, one by one, from there. Once the last error in the buffer is reached
the command has no effect and reports on this fact.
-->

<!-- panvimdoc-ignore-start -->

### `:PrevError`

Jump to a prior error in the compilation buffer. This does not take the cursor
into effect - it simply starts at the current error in the buffer and continues
backwards, one by one, from there. As long as the current error is before the
first error (the default until [`:NextError`](#nexterror) has not yet been used)
this command has no effect and reports on this fact.

<!-- panvimdoc-ignore-end -->
<!-- panvimdoc-include-comment
:PrevError

: Jump to a prior error in the compilation buffer. This does not take the cursor
into effect - it simply starts at the current error in the buffer and continues
backwards, one by one, from there. As long as the current error is before the
first error (the default until [`:NextError`](#nexterror) has not yet been used)
this command has no effect and reports on this fact.
-->

<!-- panvimdoc-ignore-start -->

### `:CompileGotoError`

Only available within the compilation buffer itself.

Jump to the error present in the line under the cursor. If no such error exists,
the command reports on this fact.

Mapped to `<CR>` within the compilation buffer.

<!-- panvimdoc-ignore-end -->
<!-- panvimdoc-include-comment
:CompileGotoError

: Only available within the compilation buffer itself.

Jump to the error present in the line under the cursor. If no such error exists,
the command reports on this fact.
-->

<!-- panvimdoc-ignore-start -->

### `:CompileInterrupt`

Only available within the compilation buffer itself.

Interrupt the currently running compilation command, reporting on this in the
compilation buffer.

Mapped to `<C-c>` within the compilation buffer.

<!-- panvimdoc-ignore-end -->
<!-- panvimdoc-include-comment
:CompileInterrupt

: Only available within the compilation buffer itself.

Interrupt the currently running compilation command, reporting on this in the
compilation buffer.

Mapped to `<C-c>` within the compilation buffer.
-->

<!-- panvimdoc-ignore-start -->

## Contributing

Contributions are welcome in the form of GitHub issues and pull requests.

For contributing details see [CONTRIBUTING.md](CONTRIBUTING.md).

<!-- panvimdoc-ignore-end -->
