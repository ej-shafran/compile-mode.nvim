## Introduction

`compile-mode.nvim` is a Neovim plugin which emulates the features of Emacs'
[Compilation
Mode](https://www.gnu.org/software/emacs/manual/html_node/emacs/Compilation-Mode.html).
It allows you to run commands which are output into a special buffer, and then
rerun that command over and over again as much as you need.

## Features

[Compile Mode Features](https://github.com/ej-shafran/compile-mode.nvim/assets/116496520/5541b9dd-70b7-4647-9c13-9e57813dac27)

## Installation

Use your favorite plugin manager. `compile-mode.nvim` depends on
[plenary.nvim](https://github.com/nvim-lua/plenary.nvim).

> [!WARNING]
>
> `compile-mode.nvim` only supports Neovim versions v0.10.0 and higher, and isn't expected to work for earlier versions.

Here's an example of a [Lazy](https://github.com/folke/lazy.nvim) config for
`compile-mode.nvim`:

```lua
return {
  "ej-shafran/compile-mode.nvim",
  version = "^5.0.0",
  -- you can just use the latest version:
  -- branch = "latest",
  -- or the most up-to-date updates:
  -- branch = "nightly",
  dependencies = {
    "nvim-lua/plenary.nvim",
    -- if you want to enable coloring of ANSI escape codes in
    -- compilation output, add:
    -- { "m00qek/baleia.nvim", tag = "v1.3.0" },
  },
  config = function()
    ---@type CompileModeOpts
    vim.g.compile_mode = {
        -- if you use something like `nvim-cmp` or `blink.cmp` for completion,
        -- set this to fix tab completion in command mode:
        -- input_word_completion = true,

        -- to add ANSI escape code support, add:
        -- baleia_setup = true,

        -- to make `:Compile` replace special characters (e.g. `%`) in
        -- the command (and behave more like `:!`), add:
        -- bang_expansion = true,
    }
  end
}
```

## Default Configuration

Here is the full default configuration:

```lua
---@module "compile-mode"
---@type CompileModeOpts
vim.g.compile_mode = {
    -- The string to show in the compile prompt as a default.
    -- For an empty prompt, you can use:
    -- default_command = "",
    -- :h compile_mode.default_command
    default_command = "make -k ",
    -- Use `baleia` for parsing ANSI escape codes in the output.
    -- :h compile_mode.baleia_setup
    baleia_setup = false,
    -- Expand commands, like `:!` (e.g. `:Compile echo %`)
    -- :h compile_mode.bang_expansion
    bang_expansion = false,
    -- Configure additional error regexes.
    -- :h compile-mode-errors
    error_regexp_table = {},
    -- List of filename regexes to ignore errors from.
    -- :h compile-mode.error_ignore_file_list
    error_ignore_file_list = {},
    -- The minimum error level to jump to.
    -- :h compile-mode.error_threshold
    error_threshold = require("compile-mode").level.WARNING,
    -- Automatically jump to the first error.
    -- :h compile-mode.auto_jump_to_first_error
    auto_jump_to_first_error = false,
    -- How long to highlight an error's location when jumping to it.
    -- :h compile-mode.error_locus_highlight
    error_locus_highlight = 500,
    -- Use Neovim diagnostics instead of opening the compilation buffer.
    -- :h compile-mode.use_diagnostics
    use_diagnostics = false,
    -- Default to calling `:Compile` for `:Recompile`
    -- when there's no previous command.
    -- :h compile-mode.recompile_no_fail
    recompile_no_fail = false,
    -- Ask to save unsaved buffers before compiling.
    -- :h compile-mode.ask_about_save
    ask_about_save = true,
    -- Ask to interrupt already running commands.
    -- :h compile-mode.ask_to_interrupt
    ask_to_interrupt = true,
    -- The name for the compilation buffer.
    -- :h compile-mode.buffer_name
    buffer_name = "*compilation*",
    -- The format for the time information
    -- at the top of the compilation buffer
    -- :h compile-mode.time_format
    time_format = "%a %b %e %H:%M:%S",
    -- List of regexes to hide from the output.
    -- :h compile-mode.hidden_output
    hidden_output = {},
    -- A table of environment variables to pass to commands.
    -- :h compile-mode.environment
    environment = nil,
    -- Clear all environment variables for each command.
    -- :h compile-mode.clear_environment
    clear_environment = false,
    -- Fix compilation for plugins like `nvim-cmp`.
    -- :h compile-mode.input_word_completion
    input_word_completion = false,
    -- Hide the compliation buffer.
    -- :h compile-mode.hidden_buffer
    hidden_buffer = false,
    -- Automatically focus the compilation buffer.
    -- :h compile-mode.focus_compilation_buffer
    focus_compilation_buffer = false,
    -- Jump back past the end/beginning of the errors
    -- with `:NextError`/`:PrevError`
    -- :h compile-mode.use_circular_error_navigation
    use_circular_error_navigation = false,
    -- Print debug information.
    -- :h compile-mode.debug
    debug = false,
    -- Use a pseudo terminal for command execution.
    -- :h compile-mode.use_pseudo_terminal
    use_pseudo_terminal = false,
}
```

## Contributing

Contributions are welcome in the form of GitHub issues and pull requests.

For contributing details see [CONTRIBUTING.md](CONTRIBUTING.md).
