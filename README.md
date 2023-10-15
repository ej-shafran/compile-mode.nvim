# Introduction

`compile-mode.nvim` is a Neovim plugin which emulates the features of Emacs' `Compilation Mode`. It allows you to run commands which are output into a special buffer, and then rerun that command over and over again as much as you need. See [Emacs Compilation Mode](https://www.gnu.org/software/emacs/manual/html_node/emacs/Compilation-Mode.html) for more details.

# API

## setup({opts})

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

Valid keys and values for {opts}

- `no_baleia_support`
  By default, `compile-mode.nvim` uses `baleia.nvim` to color in
  ANSI color escape sequences in the compilation buffer. You can
  disable this behavior by setting this config option to `true`.

- `split_vertically`
  When set to `true`, the Compilation window will be
  opened using a vertical split (|:vsplit|) instead of a
  horizontal one (|:split|).

- `default_command`
  The string to show in the |compile-mode.compile()| prompt
  as a default.
  Defaults to: `"make -k"`

## compile({param})

Run a command and place its output in the compilation buffer,
reporting on its result.

If {param.args} is not passed in, the user is prompted for a command
using |vim.ui.input()|.

### Parameters

- {param}	(table)	has a single field, `args`, which is the string of the command itself, or `nil` if the user should be prompted to enter a command (optional)

## recompile()

Rerun the last command run by [compile-mode.compile()](#compile-param). If there is no such command, the error is reported using |vim.notify()|.

# Commands

:Compile

: Runs a command and places its output in the compilation buffer.
If an argument is present, it is used as the command. Otherwise, the user is prompted using `:h vim.ui.input()`.

:Recompile

: Reruns the last compiled command. If there isn't one, the error is reported using `:h vim.notify()`.
