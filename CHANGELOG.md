# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- "Goto error" logic like in Emacs' Compilation Mode
  - The error-path syntax is highlighted
  - When the cursor is on a line that begins with an error-path syntax, pressing `<CR>` will go to that error's file, row and column
  - If the error's file is not found within the current path, the user is prompted to enter the directory to search within

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

[unreleased]: https://github.com/ej-shafran/compile-mode.nvim/compare/latest...HEAD
[1.0.3]: https://github.com/ej-shafran/compile-mode.nvim/compare/v1.0.2...v1.0.3
[1.0.2]: https://github.com/ej-shafran/compile-mode.nvim/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/ej-shafran/compile-mode.nvim/compare/v1.0.0...v1.0.1
