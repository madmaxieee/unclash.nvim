---@class State
---@field maybe_conflicted_files table<string, boolean> map of conflicted file paths
---@field hunks table<integer, ConflictHunk[]>

---@type State
local state = {
  maybe_conflicted_files = {},
  hunks = {},
}

return state
