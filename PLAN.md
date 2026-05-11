# ANSI Escape Sequence Handling — Implementation Plan

## Problem

When running commands that output ANSI escape sequences (e.g. `cargo run --color always`), non-SGR sequences like OSC 8 hyperlinks (`]8;;URL\`) pass through raw into the compilation buffer. Emacs' compilation mode handles these gracefully, but compile-mode.nvim does not.

Reference issue: https://github.com/ej-shafran/compile-mode.nvim/issues/135

## Goal

Port Emacs' `ansi-color.el` and `ansi-osc.el` behavior into compile-mode.nvim, inspired by the Emacs source:
- CSI handling: https://github.com/emacs-mirror/emacs/blob/ee9b2db1cf036d6f511d7e6eea0189073076e7c0/lisp/ansi-color.el
- OSC handling: https://github.com/emacs-mirror/emacs/blob/master/lisp/ansi-osc.el

## Config Design

```lua
vim.g.compile_mode = {
    --- Default: "render" (matches Emacs compilation mode)
    --- nil: no ANSI processing (pass through raw)
    --- "filter": strip all CSI + OSC
    --- "render": strip non-SGR CSI, render SGR via baleia, strip/handle OSC
    ansi_color_for_compilation = "render",

    --- Existing config, kept for backward compatibility
    --- boolean or table of baleia.setup() options
    --- When true/table, maps internally to ansi_color_for_compilation = "render"
    baleia_setup = false,

    --- OSC handler functions. Keys are OSC codes (integers), values are functions.
    --- When set, recognized OSC codes are handled by the corresponding function;
    --- unrecognized OSC sequences are stripped.
    --- When nil, all OSC is stripped when ansi_color_for_compilation is active.
    ansi_osc_handlers = nil,
}
```

### Behavior Matrix

| `ansi_color_for_compilation` | CSI (SGR/color) | CSI (non-SGR) | OSC |
|---|---|---|---|
| `nil` | pass through raw | pass through raw | pass through raw |
| `"filter"` | stripped | stripped | stripped |
| `"render"` | rendered by baleia | stripped | stripped (or handled by `ansi_osc_handlers`) |

### Warning Behavior

- If `ansi_color_for_compilation = "render"` and baleia can't be required → log warning, fall back to `"filter"`
- If `baleia_setup` is a non-empty table and baleia can't be required → log warning mentioning `baleia_setup`

### Backward Compatibility

- `baleia_setup = true` → internally sets `ansi_color_for_compilation = "render"`
- `baleia_setup = { some_opt = true }` → internally sets `ansi_color_for_compilation = "render"`, passes table to baleia.setup()

---

## Step 1: Create `lua/compile-mode/ansi.lua`

Core ANSI processing module. Uses `vim.regex()` to match Emacs' battle-tested
patterns from `ansi-color.el` and `ansi-osc.el`.

### Emacs Source Patterns

From `ansi-color.el`:
- Complete CSI: `\e\[[\x30-\x3F]*[\x20-\x2F]*[\x40-\x7E]`
- Partial CSI (incomplete at end of input): `\e\[[\x30-\x3F]*[\x20-\x2F]*\|\e`

From `ansi-osc.el`:
- OSC introducer: `\e]`
- OSC terminator (BEL or ST): `[\x08-\x0D]*[\x20-\x7E]*(\a\|\e\\)`

### Vim Regex Translations

Note: Emacs `\a` = BEL (0x07), but Vim `\a` = `[a-zA-Z]`, so use `\x07` instead.

```lua
-- Pattern strings for vim.fn.substitute (Vim regex syntax)
local CSI_COMPLETE_PATTERN = "\\e\\[[\\x30-\\x3F]*[\\x20-\\x2F]*[\\x40-\\x7E]"
local CSI_NON_SGR_PATTERN = "\\e\\[[\\x30-\\x3F]*[\\x20-\\x2F]*[\\x40-\\x6C\\x6E-\\x7E]"
local OSC_PATTERN = "\\e\\][\\x08-\\x0D]*[\\x20-\\x7E]*\\(\\x07\\|\\e\\\\\\)"
local PARTIAL_CSI_PATTERN = "\\e\\[[\\x30-\\x3F]*[\\x20-\\x2F]*\\|\\e$"
local PARTIAL_OSC_PATTERN = "\\e\\][^\\x07]*$"
```

All patterns are sourced directly from Emacs' ansi-color.el and ansi-osc.el,
translated to Vim regex syntax. See:
- https://github.com/emacs-mirror/emacs/blob/ee9b2db1cf036d6f511d7e6eea0189073076e7c0/lisp/ansi-color.el
- https://github.com/emacs-mirror/emacs/blob/master/lisp/ansi-osc.el

### Module State

```lua
local partial_buffer = ""
```

### Functions

1. **`strip_csi(line)`** — removes all CSI sequences:
   `return vim.fn.substitute(line, CSI_COMPLETE_PATTERN, "", "g")`

2. **`strip_non_sgr_csi(line)`** — removes non-SGR CSI only (keeps SGR ending in `m`):
   `return vim.fn.substitute(line, CSI_NON_SGR_PATTERN, "", "g")`

3. **`strip_osc(line)`** — removes all OSC sequences:
   `return vim.fn.substitute(line, OSC_PATTERN, "", "g")`

4. **`filter_line(line)`** — strips both CSI and OSC:
   `return strip_csi(strip_osc(line))`

5. **`filter_color_line(line)`** — strips non-SGR CSI and OSC (keeps SGR):
   `return strip_non_sgr_csi(strip_osc(line))`

6. **`process_line(line, mode)`** — dispatches based on mode:
   - `"filter"` → `filter_line(line)`
   - `"render"` → `filter_color_line(line)`
   - `nil` → return `line` unchanged

7. **`process_lines(lines, mode)`** — processes a list of lines with partial sequence handling:
   - Prepend `partial_buffer` to the first line
   - Reset `partial_buffer`
   - Process each line with `process_line`
   - Check if the last line ends with a partial CSI or OSC using `vim.regex(PARTIAL_CSI_PATTERN):match_str()` and `vim.regex(PARTIAL_OSC_PATTERN):match_str()`
   - If so, save the partial match to `partial_buffer`, remove it from the last line
   - Return the processed lines

8. **`reset()`** — clears `partial_buffer`. Called when a new compilation starts.

---

## Step 2: Modify `lua/compile-mode/config/internal.lua`

Add after the `baleia_setup` field (line 10):

```lua
---@type "filter"|"render"|nil
ansi_color_for_compilation = "render",
---@type table<integer, function>|nil
ansi_osc_handlers = nil,
```

Add backward compat mapping after `config.hidden_output` line (line 76):

```lua
if config.baleia_setup and config.baleia_setup ~= false then
    config.ansi_color_for_compilation = "render"
end
```

---

## Step 3: Modify `lua/compile-mode/config/meta.lua`

Add after the `baleia_setup` field annotation (line 9):

```lua
---
---Control how ANSI CSI sequences are handled in compilation output.
---Inspired by Emacs' `ansi-color-for-comint-mode`.
---`nil`: no processing (pass through raw).
---`"filter"`: strip all CSI sequences.
---`"render"`: strip non-SGR CSI, render SGR colors via baleia.
---Defaults to `"render"` to match Emacs compilation mode behavior.
---For more info, run `:h compile-mode.ansi_color_for_compilation`
---@field ansi_color_for_compilation? "filter"|"render"|nil
---
---A table mapping OSC codes to handler functions.
---Unrecognized OSC sequences are stripped when `ansi_color_for_compilation` is active.
---For more info, run `:h compile-mode.ansi_osc_handlers`
---@field ansi_osc_handlers? table<integer, fun(bufnr: integer, code: integer, text: string)>
```

---

## Step 4: Modify `lua/compile-mode/config/check.lua`

Add to the `validate` table (around line 162):

```lua
ansi_color_for_compilation = validate_enum(
    cfg.ansi_color_for_compilation,
    { ["nil"] = nil, filter = "filter", render = "render" },
    "%s"
),
ansi_osc_handlers = {
    cfg.ansi_osc_handlers,
    function(v)
        if v == nil then
            return true
        end
        if type(v) ~= "table" then
            return false
        end
        return vim.iter(pairs(v)):all(function(k, fn)
            return type(k) == "number" and type(fn) == "function"
        end)
    end,
    "table mapping OSC codes to functions",
    true,
},
```

Add `"ansi_osc_handlers"` to the `skipped_keys` list in `unrecognized_keys` (line 195):

```lua
local skipped_keys =
    { "error_regexp_table", "directory_change_matchers", "environment", "error_ignore_file_list", "hidden_output", "ansi_osc_handlers" }
```

---

## Step 5: Modify `lua/compile-mode/init.lua`

At the top (around line 24-27, with the other requires), add:

```lua
local ansi = require("compile-mode.ansi")
```

In `runjob` (around line 136, before `on_either` is defined), add:

```lua
ansi.reset()
```

In `on_either` (around line 170, after the `\r` handling block, before `set_lines`), add:

```lua
local ansi_mode = config.ansi_color_for_compilation
if ansi_mode then
    new_lines = ansi.process_lines(new_lines, ansi_mode)
end
```

---

## Step 6: Modify `ftplugin/compilation.lua`

Replace lines 7-22 (the `baleia_setup` block) with:

```lua
if config.ansi_color_for_compilation == "render" then
    local ok, baleia_mod = pcall(require, "baleia")
    if ok then
        local opts = {}
        if type(config.baleia_setup) == "table" then
            opts = config.baleia_setup --[[@as table]]
        end
        local baleia = baleia_mod.setup(opts)
        baleia.automatically(bufnr)
    else
        log.warn(
            "Could not require `baleia`. ANSI color rendering requires baleia.nvim to be installed. "
                .. "Falling back to filtering ANSI escape codes."
        )
    end
end
```

---

## Step 7: Modify `lua/compile-mode/health.lua`

Replace lines 44-48 (the baleia health check) with:

```lua
if config.ansi_color_for_compilation == "render" then
    local baleia_ok = pcall(require, "baleia")
    if not baleia_ok then
        all_ok = false
        vim.health.warn(
            "ansi_color_for_compilation is set to 'render' but baleia.nvim is not installed. "
                .. "ANSI colors will be filtered instead of rendered. Install baleia.nvim for color support."
        )
    end
end
```

---

## Step 8: Create `spec/ansi_spec.lua`

```lua
local helpers = require("spec.test_helpers")
local assert = require("luassert")

describe("ANSI escape sequence handling", function()
    before_each(helpers.setup_tests)

    it("should strip CSI sequences in filter mode", function()
        helpers.setup_tests({ ansi_color_for_compilation = "filter" })
        local cmd = "printf '\\033[2J\\033[31mhello\\033[0m\\033[K\\n'"
        helpers.compile({ args = cmd })
        local output = helpers.get_output()
        assert.are.same({ cmd, "hello" }, output)
    end)

    it("should strip OSC 8 hyperlinks in filter mode", function()
        helpers.setup_tests({ ansi_color_for_compilation = "filter" })
        local cmd = "printf 'text\\033]8;;https://example.com\\007link\\033]8;;\\007 more\\n'"
        helpers.compile({ args = cmd })
        local output = helpers.get_output()
        assert.are.same({ cmd, "textlink more" }, output)
    end)

    it("should keep SGR but strip non-SGR in render mode", function()
        helpers.setup_tests({ ansi_color_for_compilation = "render" })
        local cmd = "printf '\\033[2J\\033[31mhello\\033[0m\\033[K\\n'"
        helpers.compile({ args = cmd })
        local output = helpers.get_output()
        -- SGR (\033[31m and \033[0m) kept, non-SGR (\033[2J, \033[K) stripped
        assert.are.same({ cmd, "\27[31mhello\27[0m" }, output)
    end)

    it("should pass through raw when ansi_color_for_compilation is nil", function()
        helpers.setup_tests({ ansi_color_for_compilation = nil })
        local cmd = "printf '\\033[31mhello\\033[0m\\n'"
        helpers.compile({ args = cmd })
        local output = helpers.get_output()
        -- raw escape sequences preserved
        assert.are.same({ cmd, "\27[31mhello\27[0m" }, output)
    end)

    it("should handle cargo-style OSC 8 hyperlinks", function()
        helpers.setup_tests({ ansi_color_for_compilation = "render" })
        local cmd = "printf 'Finished \\033]8;;https://example.com\\007\\`dev\\` profile\\033]8;;\\007 target(s)\\n'"
        helpers.compile({ args = cmd })
        local output = helpers.get_output()
        assert.are.same({ cmd, "Finished \\`dev\\` profile target(s)" }, output)
    end)
end)
```

Note: Test the `printf` commands in a terminal first to verify exact output. You may need to adjust expected values.

---

## Step 9: Update `spec/carriage_return_spec.lua`

Line 38 currently expects `\27[K` to pass through raw. With the default `ansi_color_for_compilation = "render"`, `\27[K` (a non-SGR CSI) will now be stripped.

**Option A** — Update to expect stripped output (recommended):

```lua
it([[should work with other escape characters (e.g. \e[K)]], function()
    local cmd = ([[printf 'Hello, world!\r\e[K%s\n']]):format(echoed)
    helpers.compile({ args = cmd })
    assert.are.same({ cmd, echoed }, helpers.get_output())
end)
```

**Option B** — Keep old behavior by explicitly disabling ANSI processing:

```lua
it([[should work with other escape characters (e.g. \e[K)]], function()
    helpers.setup_tests({ ansi_color_for_compilation = nil })
    local cmd = ([[printf 'Hello, world!\r\e[K%s\n']]):format(echoed)
    helpers.compile({ args = cmd })
    assert.are.same({ cmd, "\27[K" .. echoed }, helpers.get_output())
end)
```

---

## Step 10: Update documentation

### `doc/compile-mode.txt`

Add a section near the baleia docs:

```
ansi_color_for_compilation              *compile-mode.ansi_color_for_compilation*
    Controls how ANSI CSI escape sequences are handled in the compilation
    output. Inspired by Emacs' `ansi-color-for-comint-mode`.

    - `nil`: No ANSI processing. All escape sequences pass through raw.
    - `"filter"`: Strip all CSI and OSC sequences from the output.
    - `"render"`: Strip non-SGR CSI sequences and OSC sequences. Keep SGR
      sequences for color rendering via baleia.nvim.

    Default: `"render"` (matches Emacs compilation mode behavior).

    When set to `"render"`, baleia.nvim must be installed for color support.
    If baleia is not available, sequences will be filtered instead.

baleia_setup                                     *compile-mode.baleia_setup*
    DEPRECATED: Use `ansi_color_for_compilation` instead.
    When `true`, equivalent to setting `ansi_color_for_compilation` to
    `"render"`. When a table, the table is passed as options to
    `baleia.setup()`.
```

Also update the table of contents.

### `README.md`

Update:
- Example config (add `ansi_color_for_compilation` and `ansi_osc_handlers`)
- Dependencies section (baleia recommended for default behavior)
- Full configuration section (add new options, mark `baleia_setup` as deprecated)

---

## Step 11: Run checks

After implementing everything:

```bash
make typecheck
make test
make fmt
```
