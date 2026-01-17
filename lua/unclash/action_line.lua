local M = {}

local state = require("unclash.state")
local ns = require("unclash.constant").ns
local hl = require("unclash.highlight")

local ACCEPT_CURRENT = "[Accept Current]"
local ACCEPT_INCOMING = "[Accept Incoming]"
local ACCEPT_BOTH = "[Accept Both]"

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
      },
    },
    virt_lines_above = true,
  })
end

local _accept_hunk = vim.schedule_wrap(M.accept_hunk)

function M.setup()
  -- run callbacks on virtual line clicks
  -- TODO: only set keymap for conflicted buffers
  vim.keymap.set("n", "<LeftMouse>", function()
    local mouse_pos = vim.fn.getmousepos()
    local clicked_buf = vim.api.nvim_win_get_buf(mouse_pos.winid)

    if not state.conflicted_bufs[clicked_buf] then
      return "<LeftMouse>"
    end

    local screen_pos = vim.fn.screenpos(mouse_pos.winid, mouse_pos.line, 0)

    -- clicked real line
    if mouse_pos.screenrow == screen_pos.row then
      return "<LeftMouse>"
    end

    local hunks = state.hunks[clicked_buf]
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
          _accept_hunk(clicked_buf, hunk, "current")
        elseif
          col >= accept_incoming_range.lower
          and col <= accept_incoming_range.upper
        then
          _accept_hunk(clicked_buf, hunk, "incoming")
        elseif
          col >= accept_both_range.lower and col <= accept_both_range.upper
        then
          _accept_hunk(clicked_buf, hunk, "both")
        end
        local current_buf = vim.api.nvim_get_current_buf()
        if clicked_buf ~= current_buf then
          -- move cursor over to clicked window
          vim.schedule(function()
            vim.api.nvim_set_current_win(mouse_pos.winid)
          end)
        end
        return ""
      end
    end

    return "<LeftMouse>"
  end, { expr = true })
end

return M
