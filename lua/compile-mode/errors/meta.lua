---@alias CompileModeIntByInt { [1]: integer, [2]: integer }
---@alias CompileModeValueAndRange<T> { range: CompileModeRange, value: T }

---@class CompileModeRange
---@field start integer
---@field end_  integer

---@class CompileModeRegexpMatcher
---@field regex    string
---@field _rx	   vim.regex|nil
---@field filename integer
---@field row      integer|CompileModeIntByInt|nil
---@field col      integer|CompileModeIntByInt|nil
---@field type     nil|CompileModeLevel|CompileModeIntByInt
---@field priority nil|integer

---@class CompileModeError
---@field highlighted boolean
---@field level       CompileModeLevel
---@field priority    integer
---@field full        CompileModeRange
---@field filename    CompileModeValueAndRange<string>
---@field row         CompileModeValueAndRange<integer>?
---@field end_row     CompileModeValueAndRange<integer>?
---@field col         CompileModeValueAndRange<integer>?
---@field end_col     CompileModeValueAndRange<integer>?
---@field group       string?
---@field full_text   string
---@field linenum     integer
