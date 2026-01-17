local M = {}

local state = require("unclash.state")

---@param bufnr number
---@param lnum number
---@return ConflictHunk|nil
function M.hunk_from_lnum(bufnr, lnum)
  local hunks = state.hunks[bufnr]
  if not hunks or #hunks == 0 then
    return nil
  end
  for _, hunk in ipairs(hunks) do
    if lnum >= hunk.current.line and lnum <= hunk.incoming.line then
      return hunk
    end
  end
  return nil
end

return M
