# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
[2.0.1]: https://github.com/ej-shafran/compile-mode.nvim/compare/v2.0.0...v2.0.1
[2.0.0]: https://github.com/ej-shafran/compile-mode.nvim/compare/v1.0.6...v2.0.0
[1.0.6]: https://github.com/ej-shafran/compile-mode.nvim/compare/v1.0.5...v1.0.6
[1.0.5]: https://github.com/ej-shafran/compile-mode.nvim/compare/v1.0.4...v1.0.5
[1.0.4]: https://github.com/ej-shafran/compile-mode.nvim/compare/v1.0.3...v1.0.4
[1.0.3]: https://github.com/ej-shafran/compile-mode.nvim/compare/v1.0.2...v1.0.3
[1.0.2]: https://github.com/ej-shafran/compile-mode.nvim/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/ej-shafran/compile-mode.nvim/compare/v1.0.0...v1.0.1
