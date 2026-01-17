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

---@param bufnr integer
---@param hunk ConflictHunk
---@param action "current" | "incoming" | "both" | "base"
function M.accept_hunk(bufnr, hunk, action)
  local lines
  if action == "current" then
    lines = vim.api.nvim_buf_get_lines(
      bufnr,
      (hunk.current.line + 1) - 1,
      (hunk.base and hunk.base.line or hunk.separator.line) - 1,
      false
    )
  elseif action == "incoming" then
    lines = vim.api.nvim_buf_get_lines(
      bufnr,
      (hunk.separator.line + 1) - 1,
      hunk.incoming.line - 1,
      false
    )
  elseif action == "both" then
    local current_lines = vim.api.nvim_buf_get_lines(
      bufnr,
      (hunk.current.line + 1) - 1,
      (hunk.base and hunk.base.line or hunk.separator.line) - 1,
      false
    )
    local incoming_lines = vim.api.nvim_buf_get_lines(
      bufnr,
      (hunk.separator.line + 1) - 1,
      hunk.incoming.line - 1,
      false
    )
    lines = vim.list_extend(current_lines, incoming_lines)
  elseif action == "base" then
    if not hunk.base then
      error("Hunk has no base to accept")
    end
    lines = vim.api.nvim_buf_get_lines(
      bufnr,
      (hunk.base.line + 1) - 1,
      hunk.separator.line - 1,
      false
    )
  else
    error("Unknown action: " .. action)
  end
  vim.api.nvim_buf_set_lines(
    bufnr,
    hunk.current.line - 1,
    (hunk.incoming.line + 1) - 1,
    false,
    lines
  )
end

return M
