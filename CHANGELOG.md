# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a
Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [5.9.0] - 2025-09-28

### Added

- Duration information in the "compilation finished" messages - by [@Sheol27](https://github.com/Sheol27)

### Fixed

- Display the correct path when using `vim.g.compilation_directory` - by [@Sheol27](https://github.com/Sheol27)

## [5.8.2] - 2025-09-13

### Fixed

- Follow the compilation window when `focus_compilation_buffer` is set, even if the compilation buffer was already open and just not focused - by [@mdnrz](https://github.com/mdnrz)
- Performance improvements - by [@Sheol27](https://github.com/Sheol27)

## [5.8.1] - 2025-09-08

### Fixed

- Moved when the `filetype` is set for the compilation buffer, which should hopefully improve performance - by [@Sheol27](https://github.com/Sheol27)

## [5.8.0] - 2025-09-04

### Added

- The `focus_compilation_buffer` option, which keeps focus on the compilation buffer when compiling - solves [#69](https://github.com/ej-shafran/compile-mode.nvim/issues/69), by [@arnevm123](https://github.com/arnevm123)

## [5.7.1] - 2025-09-04

### Fixed

- Disable swapfile for compilation buffer - fixes [#41](https://github.com/ej-shafran/compile-mode.nvim/issues/41), by [@PrescientSentinel](https://github.com/PrescientSentinel)
- Strip carriage returns from the end of lines - fixes [#72](https://github.com/ej-shafran/compile-mode.nvim/issues/72), by [@StillTree](https://github.com/StillTree)
- Removed warnings for "unrecognized keys" for the `error_ignore_file_list` and `hidden_output` options - fixes [#78](https://github.com/ej-shafran/compile-mode.nvim/issues/78), by [@arnevm123](https://github.com/arnevm123)

## [5.7.0] - 2025-07-08

### Added

- Keeping the last response to the directory prompt when a file cannot be found and reusing it when the next file cannot be found.

## [5.6.1] - 2025-04-24

### Fixed

- The number prefix which resizes the compilation buffer when compiling with `:vert`.

## [5.6.0] - 2025-04-02

### Added

- The `bang_expansion` offer, which runs commands through `expandcmd()` and makes the `:Compile` command behave more like `:!`.
- The `CompilationInterrupted` autocmd (a pattern of `User`) which triggers when the compilation is interrupted.
- The `hidden_buffer` option, which applies the old behavior where the compilation buffer is not listed.
- The `CompileCloseBuffer` command in the compilation buffer, which closes the buffer's window.

### Changed

- The behavior of the `q` keymap in the compilation buffer - it now triggers `:CompileCloseBuffer`.

### Fixed

- The default behavior for the compilation buffer's `buflisted` setting. This is possibly a breaking change for some users, for whom the `hidden_buffer` option is made available, but since this is more in line with the Emacs plugin's behavior and resolves several errors, it is marked as a fix and not a change.

## [5.5.0] - 2025-01-24

### Fixed

- The behavior of the compilation directory. The existing behavior was misleading and did not match the documentation or the Emacs plugin behavior. `:Compile` now uses the current working directory (`vim.fn.getcwd()`), unless the `vim.g.compilation_directory` global variable is set (in which case, `:Compile` unsets it once it's finished compiling); `:Recompile` now always uses the directory used by the last `:Compile`.

## [5.4.0] - 2024-11-25

### Fixed

- Issue with calling the API functions without some optional fields crashing.

## [5.3.2] - 2024-11-17

### Added

- The `CompileDebugError` command, which prints debug information about the error under the current line (along with a matching API function).

## [5.3.1] - 2024-10-30

### Added

- Documentation for minimum supported version of Neovim.

## [5.3.0] - 2024-10-13

### Changed

- The behavior of the `q` mapping within the compilation buffer; instead of running `<CMD>q<CR>` and possibly quitting Neovim, it now runs `<CMD>bdelete<CR>`, which won't close out the entire editor.
- No longer outputs additional lines created by the process once interrupted/exited.

## [5.2.0] - 2024-08-27

### Added

- The `CompilationFinished` autocmd (a pattern of `User`) which triggers when the compilation is finished.

## [5.1.0] - 2024-08-25

### Added

- A highlight of the error's locus when jumping to it, along with the `error_locus_highlight` option to configure if the highlight should occur, and for how long.
- The `priority` key for error matchers, and a default priority for the default `clang_include` matcher.
- The `:FirstError` command, which jumps to the Nth error based on the count (defaulting to 1).

## [5.0.2] - 2024-08-25

### Fixed

- Issue with completion when using `nvim-cmp`.

### Changed

- The order of the docs.

## [5.0.1] - 2024-08-24

### Fixed

- Issue with ANSI color sequences not being highlighted correctly by `baleia`.

## [5.0.0] - 2024-08-23

### Added

- The ability to use compile-mode features in any buffer with the `compilation` filetype; this means you can save command outputs in a file and reopen it to go through errors and the like.
- The `use_diagnostics` configuration option, which will cause Neovim diagnostics to be used instead of opening the compilation buffer to show errors.
- **(Breaking)** The `error_threshold` configuration option, which determines what level of errors are considered when jumping/moving between errors (i.e. using `:NextError`, `:CompileNextError`, etc.). This defaults to `compile_mode.level.WARNING`, which means that `INFO` level errors are no longer considered by default. You can set this option to `compile_mode.level.INFO` to revert to the old behavior.

### Changed

- **(Breaking)** The behavior when opening a window for compilation; instead of staying in the compilation buffer's window, compiling will now remain in the window where it originally happened. (You should note this in case you have an `autocmd` that does this behavior manually - it will now have the opposite effect in some cases, so you will likely want to remove it).

### Removed

- **(Breaking)** The `setup` function has now been completely removed. Instead, configuration should use the `vim.g.compile_mode` object, which can be given the type `CompileModeOpts`.

## [4.2.0] - 2024-08-23

### Added

- The `:NextErrorFollow` command, which previews the error under the cursor in the compilation buffer in another window.
- The ability to use `:silent` on commands which haven't been able to use it so far.

## [4.1.1] - 2024-08-22

### Fixed

- Incorrect warnings about the `environment` configuration option.

## [4.1.0] - 2024-08-18

### Added

- Custom completion for `:Compile` and the compilation input which uses Vim's `:!` completion.

## [4.0.1] - 2024-08-17

### Fixed

- Issue with compilation buffer name on Windows which resulted in "-1 is not a valid buffer id" errors.
- Passing `hidden_output` as a string now works as documented.
- Suggested commands in config type annotations.
- Several incorrect/missing warnings for configuration checks.

## [4.0.0] - 2024-08-15

### Added

- Healthchecks; you can now troubleshoot the plugin using `:checkhealth compile-mode`.
- The ability to configure the plugin using the `vim.g.compile_mode` table.
- A new type annotation for the configuration options - `CompileModeOpts`
- The plugin's logs are now also placed in `compile-mode.nvim.log` in users' `data` directory (usually something like `~/.local/share/nvim`).
- The ability to use command modifiers such as `:vert` and `:tab` with `:NextError`, `:PrevError`, `:CurrentError`, and `:CompileGotoError`. These modifiers affect the way windows are opened when jumping to errors, if a new window must be created.

### Changed

- The `setup` function is now deprecated. Instead, configuration should use the `vim.g.compile_mode` object, which can be given the type `CompileModeOpts`.
- The splitting behavior for jumping to errors; the new behavior mimics the way the Emacs mode works - use the current window, unless that window is the compilation buffer, in which case use another existing window or create a split if none exists - but enables the usage of commands like `:vertical` and other modifiers to determine the manner in which splits occur.
- Several of the type annotations have been changed to include a `CompileMode` prefix, such as:
  - `Error` -> `CompileModeError`
  - `level` -> `CompileModeLevel`
  - `RegexpMatcher` -> `CompileModeRegexpMatcher`

### Removed

- The (mostly undocumented) `same_window_errors` option.

## [3.0.1] - 2024-07-08

### Fixed

- Issue with duplicate tags in docs.

## [3.0.0] - 2024-07-07

### Added

- The ability to use `:tab` on `:Compile` and `:Recompile`.
- The ability to use a count with `NextError` and `PrevError`.
- Jumping to errors now respects "Entering directory" and "Leaving directory"
  messages from make to determine what directory a file might be in
- The `CompileNextError` and `CompilePrevError` commands, which quickly scroll
  to an error without opening its locus (i.e. source file).
- The `CompileNextFile` and `CompilePrevFile` commands, which act similarly to
  the two mentioned above but skip any errors within the current error's file.
- Several new API functions which are used to implement those commands.
- The `auto_jump_to_first_error` option, which makes compiling jump to the
  first error as soon as it is available.
- **(Breaking)** The `ask_about_save` option, which makes compiling ask about
  saving each unsaved buffer before running a command. This option is now the
  default, but it can be disabled by setting it to `false`.
- **(Breaking)** The `ask_to_interrupt` option, which makes compiling ask to
  interrupt a previously running command instead of stopping it instantly. This
  option is now the default, but it can be disabled by setting it to `false`.
- The `environment` option, which configures additional environment variables
  that each compilation command should inherit.
  - Also, add the `clear_environment` option, which modifies the behavior of
    `environment` to no longer merge with the existing environment.
- The `baleia_setup` option, which will enable support for automatic
  highlighting of ANSI escape codes when set to `true`. It can be set to a
  table of options to pass to the `baleia.setup` call.
- Proper logs for segmentation faults and command termination
- Several new keymaps within the compilation buffer
  - ...including an override of `gf` and `CTRL-W_f` that respects "Entering
    directory" and "Leaving directory" messages, as noted above for jumping to
    errors

### Changed

- Instead of printing the Emacs-style "-\*- ... -\*-" at the top of the
  compilation buffer (which does nothing in Vim), a Vim modeline is printed
  that modifies the `filetype` and `path` options in the same way that the
  original Emacs mode does.
- **(Breaking)** The `compilation_hidden_output` option has been renamed to
  `hidden_output`.
- **(Breaking)** The dependency on baleia.nvim is now optional, and can be
  enabled with the `baleia_setup` option. This means that by default, ANSI
  escape codes in the output of commands will not be highlighted.

### Removed

- **(Breaking)** The `no_baleia_support` and `baleia_options` options. As
  baleia.nvim is no longer depended upon by default, if you want to enable
  support for it within compile-mode you should use the `baleia_setup` option.
- **(Breaking)** The `error_highlights` option. Instead, customize the
  highlights defined by this plugin using Vim's regular `:highlight` command
  (see the docs).

### Fixed

- Bug with parsing of error levels that caused some of the defaults of
  `error_regexp_table` not to function properly.
- Bugs with partial output being printed to the compilation buffer, because of
  a mishandling of partial lines returned from `jobstart()`.

## [2.8.0] - 2024-05-22

### Added

- The `CurrentError` command, which acts as a way to jump back to the error you
  were working after a bit of iteration.
- The `QuickfixErrors` command, which sends compilation errors to the quickfix
  list and opens the quickfix window.
- Several new API functions which are used to implement those commands.

### Changed

- The documentation process; the docs themselves are no longer created from the
  README, which creates better, more readable docs and a cleaner, simpler
  README.

## [2.7.1] - 2024-05-21

### Fixed

- The behavior of certain unique characters in the name of the compilation
  buffer. Specifically, this fixes an issue with the default buffer name - see
  [here](https://github.com/ej-shafran/compile-mode.nvim/issues/16).

## [2.7.0] - 2024-05-20

### Changed

- Changed the `buftype` of the compilation buffer to `"nofile"`.

### Fixed

- Moved the compilation buffer commands out of an `autocmd` to resolve some
  weird issues with it
- Make `count` argument of `compile()` and `recompile()` optional

## [2.6.1] - 2024-02-27

### Fixed

- Table-of-contents in the docs

## [2.6.0] - 2024-02-27

### Fixed

- The behavior of the `PrevError` command and relevant API functions; it no
  longer jumps to the earliest error instead of one before the current one

### Added

- The ability to use `:hide` on the compilation commands to hide the
  compilation buffer

## [2.5.0] - 2023-12-23

### Changed

- The `buftype` of the compilation buffer to `acwrite`, to disable accidental
  writing of the buffer (see [this
  issue](https://github.com/ej-shafran/compile-mode.nvim/issues/10))

## [2.4.0] - 2023-12-14

### Changed

- The default window behavior for jumping to errors (see [this
  issue](https://github.com/ej-shafran/compile-mode.nvim/issues/8))

### Added

- The `same_window_errors` option, which overrides the new default window
  behavior and opens errors in the current window

## [2.3.1] - 2023-12-03

### Fixed

- Auto-scrolling behavior not working when not focused on the buffer

## [2.3.0] - 2023-12-01

### Added

- Auto-scrolling behavior for the compilation buffer

## [2.2.0] - 2023-11-28

### Added

- The `recompile_no_fail` option, which causes `:Recompile` not to fail without
  a previous command but instead to call `:Compile`

## [2.1.1] - 2023-11-24

### Fixed

- Error when interrupting a command ("buffer not modifiable...")

## [2.1.0] - 2023-11-24

### Added

- The `:CompileInterrupt` command, which allows canceling the currently running
  compilation

## [2.0.2] - 2023-11-24

## Fixed

- The current error (used for `:NextError` and `:PrevError`) not resetting when
  compilation restarts

## [2.0.1] - 2023-11-24

### Fixed

- Error when calling `:NextError` after the last error or calling `:PrevError`
  before the first error

## [2.0.0] - 2023-11-20

### Added

- Error logic like in Emacs' Compilation Mode
  - An error-regex table which defines errors and how they are highlighted
    - The error-regex table can be altered using `setup()` and the
      `error_regexp_table` option
  - A `CompileGotoError` command within the compilation buffer that jumps to
    that error's file, row, and column
    - If the error's file is not found within the current path, the user is
      prompted to enter the directory to search within
  - The errors can be specified to have different levels (error, warning,
    info), and are highlighted accordingly
    - The colors for errors can be customized using `setup()` and the
      `error_highlights` option,
    - The colors for errors default to using Neovim's current color theme
  - The `NextError` and `PrevError` commands, which can be used (along with
    matching API functions) to jump between parsed errors
- A `debug` option for `setup()` that prints additional information, useful for
  development
- Running `:Compile` and `:Recompile` with a `!` (bang) runs the command
  synchronously
- Running `:Compile` and `:Recompile` with a count (i.e. `:[N]Compile`) creates
  the compilation buffer using `:[N]split` (see [this
  issue](https://github.com/ej-shafran/compile-mode.nvim/issues/2))

### Changed

- **(Breaking)** The `setup` function is now mandatory, as it sets up several
  key features of the error logic

### Fixed

- Running a compilation command while another one is in process kills the
  original process using `jobstop`, and reports this interruption in the
  compilation buffer

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

- The ability to use `:aboveleft`, `:belowright`, `:topleft` and `:botright`
  with the `:Compile` and `:Recompile` commands
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

- Usage of the previously used current working directory when using `recompile`
  or `:Recompile`

### Removed

- The `split_vertically` configuration option; use `:vert` instead

### Added

- This CHANGELOG file
- The ability to use `:vert` with the `:Compile` and `:Recompile` commands
  - Also the ability to pass the `smods` field (and `smods.vertical`) to the
    API functions

[unreleased]: https://github.com/ej-shafran/compile-mode.nvim/compare/latest...nightly
[5.9.0]: https://github.com/ej-shafran/compile-mode.nvim/compare/v5.8.2...v5.9.0
[5.8.2]: https://github.com/ej-shafran/compile-mode.nvim/compare/v5.8.1...v5.8.2
[5.8.1]: https://github.com/ej-shafran/compile-mode.nvim/compare/v5.8.0...v5.8.1
[5.8.0]: https://github.com/ej-shafran/compile-mode.nvim/compare/v5.7.1...v5.8.0
[5.7.1]: https://github.com/ej-shafran/compile-mode.nvim/compare/v5.7.0...v5.7.1
[5.7.0]: https://github.com/ej-shafran/compile-mode.nvim/compare/v5.6.1...v5.7.0
[5.6.1]: https://github.com/ej-shafran/compile-mode.nvim/compare/v5.6.0...v5.6.1
[5.6.0]: https://github.com/ej-shafran/compile-mode.nvim/compare/v5.5.0...v5.6.0
[5.5.0]: https://github.com/ej-shafran/compile-mode.nvim/compare/v5.4.0...v5.5.0
[5.4.0]: https://github.com/ej-shafran/compile-mode.nvim/compare/v5.3.2...v5.4.0
[5.3.2]: https://github.com/ej-shafran/compile-mode.nvim/compare/v5.3.1...v5.3.2
[5.3.1]: https://github.com/ej-shafran/compile-mode.nvim/compare/v5.3.0...v5.3.1
[5.3.0]: https://github.com/ej-shafran/compile-mode.nvim/compare/v5.2.0...v5.3.0
[5.2.0]: https://github.com/ej-shafran/compile-mode.nvim/compare/v5.1.0...v5.2.0
[5.1.0]: https://github.com/ej-shafran/compile-mode.nvim/compare/v5.0.2...v5.1.0
[5.0.2]: https://github.com/ej-shafran/compile-mode.nvim/compare/v5.0.1...v5.0.2
[5.0.1]: https://github.com/ej-shafran/compile-mode.nvim/compare/v5.0.0...v5.0.1
[5.0.0]: https://github.com/ej-shafran/compile-mode.nvim/compare/v4.2.0...v5.0.0
[4.2.0]: https://github.com/ej-shafran/compile-mode.nvim/compare/v4.1.1...v4.2.0
[4.1.1]: https://github.com/ej-shafran/compile-mode.nvim/compare/v4.1.0...v4.1.1
[4.1.0]: https://github.com/ej-shafran/compile-mode.nvim/compare/v4.0.1...v4.1.0
[4.0.1]: https://github.com/ej-shafran/compile-mode.nvim/compare/v4.0.0...v4.0.1
[4.0.0]: https://github.com/ej-shafran/compile-mode.nvim/compare/v3.0.1...v4.0.0
[3.0.1]: https://github.com/ej-shafran/compile-mode.nvim/compare/v3.0.0...v3.0.1
[3.0.0]: https://github.com/ej-shafran/compile-mode.nvim/compare/v2.8.0...v3.0.0
[2.8.0]: https://github.com/ej-shafran/compile-mode.nvim/compare/v2.7.1...v2.8.0
[2.7.1]: https://github.com/ej-shafran/compile-mode.nvim/compare/v2.7.0...v2.7.1
[2.7.0]: https://github.com/ej-shafran/compile-mode.nvim/compare/v2.6.1...v2.7.0
[2.6.1]: https://github.com/ej-shafran/compile-mode.nvim/compare/v2.6.0...v2.6.1
[2.6.0]: https://github.com/ej-shafran/compile-mode.nvim/compare/v2.5.0...v2.6.0
[2.5.0]: https://github.com/ej-shafran/compile-mode.nvim/compare/v2.4.0...v2.5.0
[2.4.0]: https://github.com/ej-shafran/compile-mode.nvim/compare/v2.3.1...v2.4.0
[2.3.1]: https://github.com/ej-shafran/compile-mode.nvim/compare/v2.3.0...v2.3.1
[2.3.0]: https://github.com/ej-shafran/compile-mode.nvim/compare/v2.2.0...v2.3.0
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
