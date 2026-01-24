---@class unclash.State
---@field maybe_conflicted_files table<string, boolean> map of conflicted file paths
---@field hunks table<integer, ConflictHunk[]>

---@type unclash.State
local state = {
  maybe_conflicted_files = {},
  hunks = {},
}

return state
