# Contributing

Thank you for wanting to contribute to `compile-mode.nvim`! Generally, I want to keep this plugin pretty close to the features of Emacs' Compilation Mode, with better quality of life where possible, so I'd recommend you have some familiarity with it if you want to contribute. Bug fixes are always welcome, of course, but new features should either be things that exist in the Emacs mode or things that unambiguously make the plugin nicer to use.

> [!NOTE]
>
> As specified in the README, `compile-mode.nvim` only officially supports Neovim versions v0.10.0 and higher. However, if you'd like to contribute some code that makes the plugin work for earlier versions (and isn't too much of a hassle to maintain) I'll be glad to merge it.

## The development process

### Cloning the repository

Fork the repository and clone it. It's better if you work from the `nightly` branch, so make sure you fork the repo with all its branches and not just `main`.

### Using your local changes in Neovim

If you have a clone of the project (or your fork of it) just using `vim.opt.rtp:append "~/path/to/compile-mode.nvim"` will make the plugin work as expected.

Your plugin manager of choice may have their own way of configuring "locally loaded" plugins - e.g. if you're using Lazy, you can use the `dir` option of the Lazy spec.

## CI

This repository has several continuous integration checks. Any pull request that doesn't pass CI won't get merged.

### Testing

The tests use `plenary.nvim`'s `busted` style testing. Read their [tests README](https://github.com/nvim-lua/plenary.nvim/blob/master/TESTS_README.md) for more info.

Please add testing for any new features you add. It would also be nice if you added tests to show any bugs that you intend to solve.

Obviously, please don't break any existing tests. If your PR changes the behavior in a way that would break the tests and you change the tests to fit, please clarify this in the comments on the PR.

You can run tests locally with `make test` (or `make test-debug`, which shows debug logs).

### Formatting

The files are formatted using [stylua](https://github.com/JohnnyMorganz/StyLua). If you have it installed, you can format the files using `make fmt`.

### Typechecking

The Lua code is typechecked using [lua-language-server](https://luals.github.io/#other-install). If you have it installed, you can check the validity of the code using `make typecheck` (or by directly running `./typecheck.sh`).
