local M = {}

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
  -- wrap around to the last hunk
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

-- TODO: add accept action api for keymap and commands
-- TODO: read from predefined DiffAdd colors
-- TODO: add snakcs picker to find conflict location
-- TODO: write readme
-- TODO: show warning if rg is not present?
-- TODO: use in-process LSP to provide code actions for resolving conflicts?
-- TODO: implement vscode-like merge editor
