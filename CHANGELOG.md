# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- The `CompileNextError` and `CompilePrevError` commands, which quickly scroll to an error without opening its locus (i.e. source file).
- The `CompileNextFile` and `CompilePrevFile` commands, which act similarly to the two mentioned above but skip any errors within the current error's file.
- Several new API functions which are used to implement those commands.

### Changed

- Instead of printing the Emacs-style "-*- ... -*-" at the top of the compilation buffer (which does nothing in Vim), a Vim modeline is printed that modifies the `filetype` and `path` options in the same way that the original Emacs mode does.

### Removed

- **(Breaking)** The dependency on `baleia.nvim`, along with the `no_baleia_support` and `baleia_options` options. This means that ANSI escape codes will no longer be automatically highlighted inside of the compilation buffer.
- **(Breaking)** The `error_highlights` option. Instead, customize the highlights defined by this plugin using Vim's regular `:highlight` command (see the docs).

### Fixed

- Bug with parsing of error levels that caused some of the defaults of `error_regexp_table` not to function properly.

## [2.8.0] - 2024-05-22

### Added

- The `CurrentError` command, which acts as a way to jump back to the error you were working after a bit of iteration.
- The `QuickfixErrors` command, which sends compilation errors to the quickfix list and opens the quickfix window.
- Several new API functions which are used to implement those commands.

### Changed

- The documentation process; the docs themselves are no longer created from the README, which creates better, more readable docs and a cleaner, simpler README.

## [2.7.1] - 2024-05-21

### Fixed

- The behavior of certain unique characters in the name of the compilation buffer. Specifically, this fixes an issue with the default buffer name - see [here](https://github.com/ej-shafran/compile-mode.nvim/issues/16).

## [2.7.0] - 2024-05-20

### Changed

- Changed the `buftype` of the compilation buffer to `"nofile"`.

### Fixed

- Moved the compilation buffer commands out of an `autocmd` to resolve some weird issues with it
- Make `count` argument of `compile()` and `recompile()` optional

## [2.6.1] - 2024-02-27

### Fixed

- Table-of-contents in the docs

## [2.6.0] - 2024-02-27

### Fixed

- The behavior of the `PrevError` command and relevant API functions; it no longer jumps to the earliest error instead of one before the current one

### Added

- The ability to use `:hide` on the compilation commands to hide the compilation buffer

## [2.5.0] - 2023-12-23

### Changed

- The `buftype` of the compilation buffer to `acwrite`, to disable accidental writing of the buffer (see [this issue](https://github.com/ej-shafran/compile-mode.nvim/issues/10))

## [2.4.0] - 2023-12-14

### Changed

- The default window behavior for jumping to errors (see [this issue](https://github.com/ej-shafran/compile-mode.nvim/issues/8))

### Added

- The `same_window_errors` option, which overrides the new default window behavior and opens errors in the current window

## [2.3.1] - 2023-12-03

### Fixed

- Auto-scrolling behavior not working when not focused on the buffer

## [2.3.0] - 2023-12-01

### Added

- Auto-scrolling behavior for the compilation buffer

## [2.2.0] - 2023-11-28

### Added

- The `recompile_no_fail` option, which causes `:Recompile` not to fail without a previous command but instead to call `:Compile`

## [2.1.1] - 2023-11-24

### Fixed

- Error when interrupting a command ("buffer not modifiable...")

## [2.1.0] - 2023-11-24

### Added

- The `:CompileInterrupt` command, which allows canceling the currently running compilation

## [2.0.2] - 2023-11-24

## Fixed

- The current error (used for `:NextError` and `:PrevError`) not resetting when compilation restarts

## [2.0.1] - 2023-11-24

### Fixed

- Error when calling `:NextError` after the last error or calling `:PrevError` before the first error

## [2.0.0] - 2023-11-20

### Added

- Error logic like in Emacs' Compilation Mode
  - An error-regex table which defines errors and how they are highlighted
    - The error-regex table can be altered using `setup()` and the `error_regexp_table` option
  - A `CompileGotoError` command within the compilation buffer that jumps to that error's file, row, and column
    - If the error's file is not found within the current path, the user is prompted to enter the directory to search within
  - The errors can be specified to have different levels (error, warning, info), and are highlighted accordingly
    - The colors for errors can be customized using `setup()` and the `error_highlights` option,
    - The colors for errors default to using Neovim's current color theme
  - The `NextError` and `PrevError` commands, which can be used (along with matching API functions) to jump between parsed errors
- A `debug` option for `setup()` that prints additional information, useful for development
- Running `:Compile` and `:Recompile` with a `!` (bang) runs the command synchronously
- Running `:Compile` and `:Recompile` with a count (i.e. `:[N]Compile`) creates the compilation buffer using `:[N]split` (see [this issue](https://github.com/ej-shafran/compile-mode.nvim/issues/2))

### Changed

- **(Breaking)** The `setup` function is now mandatory, as it sets up several key features of the error logic

### Fixed

- Running a compilation command while another one is in process kills the original process using `jobstop`, and reports this interruption in the compilation buffer

## [1.0.6] - 2023-11-01

### Fixed

- The behavior of the compilation buffer
  - It now always shows up as `nomodified`
  - It no longer tries to call `nvim_api_delete_buf` with an invalid buffer
- Error with trying to call "Compilation" command
- Spelling in README

## [1.0.5] - 2023-10-31

### Fixed

- `:vert` having the opposite effect on commands and API functions

## [1.0.4] - 2023-10-29

### Fixed

- Documentation and README is updated to include `buffer_name` as an option.

## [1.0.3] - 2023-10-29

### Added

- The ability to use `:aboveleft`, `:belowright`, `:topleft` and `:botright` with the `:Compile` and `:Recompile` commands
  - Also the ability to pass `smods.split` to the API functions
- Configuration option for the compilation buffer name (`buffer_name`)

## [1.0.2] - 2023-10-29

### Fixed

- The compilation buffer is no longer modifiable by default

### Added

- The ability to use `:silent` with the `:Compile` and `:Recompile` commands
  - Also the ability to pass `smods.silent` to the API functions

## [1.0.1] - 2023-10-27

### Fixed

- Usage of the previously used current working directory when using `recompile` or `:Recompile`

### Removed

- The `split_vertically` configuration option; use `:vert` instead

### Added

- This CHANGELOG file
- The ability to use `:vert` with the `:Compile` and `:Recompile` commands
  - Also the ability to pass the `smods` field (and `smods.vertical`) to the API functions

[unreleased]: https://github.com/ej-shafran/compile-mode.nvim/compare/latest...nightly
[2.8.0]: https://github.com/ej-shafran/compile-mode.nvim/compare/v2.7.1...v2.8.0
[2.7.1]: https://github.com/ej-shafran/compile-mode.nvim/compare/v2.7.0...v2.7.1
[2.7.0]: https://github.com/ej-shafran/compile-mode.nvim/compare/v2.6.1...v2.7.0
[2.6.1]: https://github.com/ej-shafran/compile-mode.nvim/compare/v2.6.0...v2.6.1
[2.6.0]: https://github.com/ej-shafran/compile-mode.nvim/compare/v2.5.0...v2.6.0
[2.5.0]: https://github.com/ej-shafran/compile-mode.nvim/compare/v2.4.0...v2.5.0
[2.4.0]: https://github.com/ej-shafran/compile-mode.nvim/compare/v2.3.1...v2.4.0
[2.3.1]: https://github.com/ej-shafran/compile-mode.nvim/compare/v2.3.0...v2.3.1
[2.2.0]: https://github.com/ej-shafran/compile-mode.nvim/compare/v2.1.1...v2.2.0
[2.1.1]: https://github.com/ej-shafran/compile-mode.nvim/compare/v2.1.0...v2.1.1
[2.1.0]: https://github.com/ej-shafran/compile-mode.nvim/compare/v2.0.2...v2.1.0
[2.0.2]: https://github.com/ej-shafran/compile-mode.nvim/compare/v2.0.1...v2.0.2
[2.0.1]: https://github.com/ej-shafran/compile-mode.nvim/compare/v2.0.0...v2.0.1
[2.0.0]: https://github.com/ej-shafran/compile-mode.nvim/compare/v1.0.6...v2.0.0
[1.0.6]: https://github.com/ej-shafran/compile-mode.nvim/compare/v1.0.5...v1.0.6
[1.0.5]: https://github.com/ej-shafran/compile-mode.nvim/compare/v1.0.4...v1.0.5
[1.0.4]: https://github.com/ej-shafran/compile-mode.nvim/compare/v1.0.3...v1.0.4
[1.0.3]: https://github.com/ej-shafran/compile-mode.nvim/compare/v1.0.2...v1.0.3
[1.0.2]: https://github.com/ej-shafran/compile-mode.nvim/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/ej-shafran/compile-mode.nvim/compare/v1.0.0...v1.0.1
