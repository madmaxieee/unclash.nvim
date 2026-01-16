local M = {}

local state = require("unclash.state")
local ns = require("unclash.constant").ns
local hl = require("unclash.highlight")

local ACCEPT_CURRENT = "[Accept Current]"
local ACCEPT_INCOMING = "[Accept Incoming]"
local ACCEPT_BOTH = "[Accept Both]"
local ACCEPT_NONE = "[Accept None]"

local _cursor = 0
local accept_current_range = {
  lower = _cursor,
  upper = _cursor + #ACCEPT_CURRENT - 1,
}
_cursor = _cursor + #ACCEPT_CURRENT + 1
local accept_incoming_range = {
  lower = _cursor,
  upper = _cursor + #ACCEPT_INCOMING - 1,
}
_cursor = _cursor + #ACCEPT_INCOMING + 1
local accept_both_range = {
  lower = _cursor,
  upper = _cursor + #ACCEPT_BOTH - 1,
}
_cursor = _cursor + #ACCEPT_BOTH + 1
local accept_none_range = {
  lower = _cursor,
  upper = _cursor + #ACCEPT_NONE - 1,
}

---@param bufnr integer
---@param hunk ConflictHunk
---@param action "current" | "incoming" | "both" | "none"
local function accept_hunk(bufnr, hunk, action)
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
  elseif action == "none" then
    lines = {}
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

---@param bufnr integer
---@param line integer
function M.draw_action_line(bufnr, line)
  vim.api.nvim_buf_set_extmark(bufnr, ns, line - 1, 0, {
    virt_lines = {
      {
        { ACCEPT_CURRENT, hl.groups.action_button },
        { " ", hl.groups.action_line },
        { ACCEPT_INCOMING, hl.groups.action_button },
        { " ", hl.groups.action_line },
        { ACCEPT_BOTH, hl.groups.action_button },
        { " ", hl.groups.action_line },
        { ACCEPT_NONE, hl.groups.action_button },
      },
    },
    virt_lines_above = true,
  })
end

function M.setup()
  -- run callbacks on virtual line clicks
  -- TODO: only set keymap for conflicted buffers
  vim.keymap.set("n", "<LeftMouse>", function()
    local bufnr = vim.api.nvim_get_current_buf()
    if not state.conflicted_bufs[bufnr] then
      return "<LeftMouse>"
    end

    local mouse_pos = vim.fn.getmousepos()
    local screen_pos = vim.fn.screenpos(mouse_pos.winid, mouse_pos.line, 0)

    -- clicked real line
    if mouse_pos.screenrow == screen_pos.row then
      return "<LeftMouse>"
    end

    local hunks = state.hunks[bufnr]
    if not hunks or #hunks == 0 then
      return "<LeftMouse>"
    end

    -- TODO: use binary search
    for _, hunk in ipairs(hunks) do
      if mouse_pos.line == hunk.current.line then
        -- calculate the real "buffer column" of the mouse click
        -- can't use mouse_pos.col because it only works on actual lines
        local col = mouse_pos.screencol - screen_pos.col
        if
          col >= accept_current_range.lower
          and col <= accept_current_range.upper
        then
          vim.schedule_wrap(accept_hunk)(bufnr, hunk, "current")
        elseif
          col >= accept_incoming_range.lower
          and col <= accept_incoming_range.upper
        then
          vim.schedule_wrap(accept_hunk)(bufnr, hunk, "incoming")
        elseif
          col >= accept_both_range.lower and col <= accept_both_range.upper
        then
          vim.schedule_wrap(accept_hunk)(bufnr, hunk, "both")
        elseif
          col >= accept_none_range.lower and col <= accept_none_range.upper
        then
          vim.schedule_wrap(accept_hunk)(bufnr, hunk, "none")
        end
        return ""
      end
    end

    return "<LeftMouse>"
  end, { expr = true })
end

return M
