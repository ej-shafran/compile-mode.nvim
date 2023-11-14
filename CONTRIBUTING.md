# Contributing

Thank you for wanting to contribute to `compile-mode.nvim`! Generally, I want to keep this plugin pretty close to the features of Emacs' Compilation Mode, with better quality of life where possible, so I'd recommend you have some familiarity with it if you want to contribute. Bug fixes are always welcome, of course, but new features should either be things that exist in the Emacs mode or things that unambiguously make the plugin nicer to use.

## The development process

### Cloning the repository

Fork the repository and clone it.

### Makefile

The Makefile has commands for `test`, `fmt`, and `lint`. These commands do exactly what you would expect.

### Using your local changes in Neovim

If you're using Lazy, use the `dir` option of the Lazy spec to keep your plugin up-to-date with your development version, without having to push your changes remotely. You can use the `Lazy reload` command to reload the plugin - it should work properly, unless you've changed the highlight groups, in which case restarting Neovim might be needed.

## Testing

The tests use `plenary.nvim`'s `busted` style testing. Read their [tests README](https://github.com/nvim-lua/plenary.nvim/blob/master/TESTS_README.md) for more info.

Please add testing for any new features you add. It would also be nice if you added tests to show any bugs that you intend to solve.

Obviously, please don't break any existing tests. I won't merge a pull request that doesn't have its GitHub checks passing. If your PR changes the behavior in a way that would break the tests and you change the tests to fit, please clarify this in the comments on the PR.
