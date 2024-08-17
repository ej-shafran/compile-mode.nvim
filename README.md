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

Here's an example of a [Lazy](https://github.com/folke/lazy.nvim) config for
`compile-mode.nvim`:

```lua
return {
  "ej-shafran/compile-mode.nvim",
  branch = "latest",
  -- or a specific version:
  -- tag = "v4.0.0"
  dependencies = {
    "nvim-lua/plenary.nvim",
    -- if you want to enable coloring of ANSI escape codes in
    -- compilation output, add:
    -- { "m00qek/baleia.nvim", tag = "v1.3.0" },
  },
  config = function()
    ---@type CompileModeOpts
    vim.g.compile_mode = {
        -- to add ANSI escape code support, add:
        -- baleia_setup = true,
    }
  end
}
```

## Contributing

Contributions are welcome in the form of GitHub issues and pull requests.

For contributing details see [CONTRIBUTING.md](CONTRIBUTING.md).
