local M = {}

local state = require("unclash.state")
local action_line = require("unclash.action_line")

---@param action "current" | "incoming" | "both" | "none"
function M.accept(action)
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local hunks = state.hunks[bufnr]
  if not hunks or #hunks == 0 then
    vim.notify("No conflicts detected in this file", vim.log.levels.INFO)
    return
  end
  for _, hunk in ipairs(hunks) do
    if cursor[1] >= hunk.current.line and cursor[1] <= hunk.incoming.line then
      -- cursor is within this hunk
      local ok, err = pcall(function()
        action_line.accept_hunk(bufnr, hunk, action)
      end)
      if not ok then
        vim.notify("Failed to accept changes: " .. err, vim.log.levels.ERROR)
      end
      return
    end
  end
  vim.notify("Cursor is not within a conflict hunk", vim.log.levels.WARN)
end

function M.accept_current()
  M.accept("current")
end

function M.accept_incoming()
  M.accept("incoming")
end

function M.accept_both()
  M.accept("both")
end

function M.accept_none()
  M.accept("none")
end

---@param opts? {wrap?: boolean, bottom?: boolean}
function M.next_conflict(opts)
  opts = opts or {}
  local bufnr = vim.api.nvim_get_current_buf()
  local hunks = state.hunks[bufnr]
  if not hunks or #hunks == 0 then
    vim.notify("No conflicts detected in this file", vim.log.levels.INFO)
    return
  end
  local cursor = vim.api.nvim_win_get_cursor(0)
  local marker_type = opts.bottom and "incoming" or "current"
  for _, hunk in ipairs(hunks) do
    if hunk[marker_type].line > cursor[1] then
      vim.api.nvim_win_set_cursor(0, { hunk[marker_type].line, 0 })
      return
    end
  end
  -- wrap around to the first hunk
  if opts.wrap then
    if hunks and #hunks > 0 then
      vim.api.nvim_win_set_cursor(0, { hunks[1].current.line, 0 })
    end
  end
end

---@param opts? {wrap?: boolean, bottom?: boolean}
function M.prev_conflict(opts)
  opts = opts or {}
  local bufnr = vim.api.nvim_get_current_buf()
  local hunks = state.hunks[bufnr]
  if not hunks or #hunks == 0 then
    vim.notify("No conflicts detected in this file", vim.log.levels.INFO)
    return
  end
  local cursor = vim.api.nvim_win_get_cursor(0)
  local marker_type = opts.bottom and "incoming" or "current"
  for i = #hunks, 1, -1 do
    local hunk = hunks[i]
    if hunk[marker_type].line < cursor[1] then
      vim.api.nvim_win_set_cursor(0, { hunk[marker_type].line, 0 })
      return
    end
  end
  -- wrap around to the last hunk
  if opts.wrap then
    if hunks and #hunks > 0 then
      vim.api.nvim_win_set_cursor(0, { hunks[#hunks].current.line, 0 })
    end
  end
end

return M

-- TODO: read from predefined DiffAdd colors
-- TODO: add snakcs picker to find conflict location
-- TODO: write readme
-- TODO: show warning if rg is not present?
-- TODO: implement vscode-like merge editor
