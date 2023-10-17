## Introduction

`compile-mode.nvim` is a Neovim plugin which emulates the features of Emacs' `Compilation Mode`. It allows you to run commands which are output into a special buffer, and then rerun that command over and over again as much as you need. See [Emacs Compilation Mode](https://www.gnu.org/software/emacs/manual/html_node/emacs/Compilation-Mode.html) for more details.

## Installation

Use your favorite plugin manager. `compile-mode.nvim` depends on `nvim-lua/plenary.nvim` and on `m00qek/baleia.nvim` (unless the [`no_baleia_support`](#no_baleia_support) option is set).

Here's an example of a [Lazy](https://github.com/folke/lazy.nvim) config for `compile-mode.nvim`:

```lua
return {
  "ej-shafran/compile-mode.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    { "m00qek/baleia.nvim", tag = "v1.3.0" },
  },
  opts = {
    -- you can disable colors by uncommenting this line
    -- no_baleia_support = true,
    split_vertically = true,
    default_command = "npm run build"
  }
}
```

## API

<!-- panvimdoc-ignore-start -->

### setup({opts})

<!-- panvimdoc-ignore-end -->
<!-- panvimdoc-include-comment
```vimdoc
compile_mode.setup({opts})	  				  *compile-mode.setup()*
```
-->

You don't have to call `compile_mode.setup()` for the plugin to work; it just allows you to configure the plugin to your needs.

Usage:

```lua
require("compile-mode").setup({
    -- you can disable colors by uncommenting this line
    -- no_baleia_support = true,
    split_vertically = true,
    default_command = "npm run build"
})
```

Valid keys and values for {opts}:

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

#### `split_vertically`

When set to `true`, the Compilation window will be opened using a vertical split (`:h :vsplit`) instead of a horizontal one (`:h :split`).

<!-- panvimdoc-ignore-end -->
<!-- panvimdoc-include-comment
split_vertically

: When set to `true`, the Compilation window will be opened using a vertical split (`:h :vsplit`) instead of a horizontal one (`:h :split`).
-->

<!-- panvimdoc-ignore-start -->

#### `default_command`

The string to show in the `compile()` prompt as a default.
Defaults to: `"make -k "`.

<!-- panvimdoc-ignore-end -->
<!-- panvimdoc-include-comment
default_command

: The string to show in the |compile-mode.compile()| prompt as a default.
Defaults to: `"make -k "`
-->

<!-- panvimdoc-ignore-start -->

#### `time_format`

The way to format the time displayed at the top of the Compilation buffer. Passed into `:h strftime()`.
Defaults to: `"%a %b %e %H:%M:%S"`.

<!-- panvimdoc-ignore-end -->
<!-- panvimdoc-include-comment
time_format

: The way to format the time displayed at the top of the Compilation buffer. Passed into `:h strftime()`.
Defaults to: `"%a %b %e %H:%M:%S"`.
-->

<!-- panvimdoc-ignore-start -->

#### `baleia_options`

<!-- panvimdoc-ignore-end -->

Table of options to pass into `baleia.setup()`.
Defaults to an empty table

<!-- panvimdoc-include-comment
baleia_options

: Table of options to pass into `baleia.setup()`.
Defaults to an empty table
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
If `{param.args}` is not passed in, the user is prompted for a command using `:h vim.ui.input()`.

#### Parameters

- `{param}` (table) has a single field, `args`, which is the string of the command itself, or `nil` if the user should be prompted to enter a command (optional)

<!-- panvimdoc-ignore-start -->

### recompile()

<!-- panvimdoc-ignore-end -->
<!-- panvimdoc-include-comment
```vimdoc
compile_mode.recompile()					*compile-mode.recompile()*
```
-->

Reruns the last compiled command. If there isn't one, the error is reported using `:h vim.notify()`.
The command is rerun from the directory in which it was originally run.

## Commands

<!-- panvimdoc-ignore-start -->

### `:Compile`

Runs a command and places its output in the compilation buffer.
The command is run from the current working directory.
If an argument is present, it is used as the command. Otherwise, the user is prompted using `:h vim.ui.input()`.

<!-- panvimdoc-ignore-end -->
<!-- panvimdoc-include-comment
:Compile
: Runs a command and places its output in the compilation buffer.
The command is run from the current working directory.
If an argument is present, it is used as the command. Otherwise, the user is prompted using `:h vim.ui.input()`.

-->

<!-- panvimdoc-ignore-start -->

### `:Recompile`

Reruns the last compiled command. If there isn't one, the error is reported using `:h vim.notify()`.
The command is rerun from the directory in which it was originally run.

<!-- panvimdoc-ignore-end -->
<!-- panvimdoc-include-comment
:Recompile

: Reruns the last compiled command. If there isn't one, the error is reported using `:h vim.notify()`.
The command is rerun from the directory in which it was originally run.
-->

<!-- panvimdoc-ignore-start -->

## Contributing

Contributions are welcome in the form of GitHub issues and pull requests.

<!-- panvimdoc-ignore-end -->
