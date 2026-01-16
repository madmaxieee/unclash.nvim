---@class State
---@field conflicted_files table<string, boolean> map of conflicted file paths
---@field conflicted_bufs table<integer, boolean> map of conflicted buffer numbers
---@field hunks table<integer, ConflictHunk[]>

---@type State
local state = {
  conflicted_files = {},
  conflicted_bufs = {},
  hunks = {},
}

return state
