local M = {}

local conflict = require("unclash.conflict")
local hl = require("unclash.highlight")
local state = require("unclash.state")
local utils = require("unclash.utils")

local ns = require("unclash.constant").ns

---@class MergeEditorState
---@field enabled boolean
---@field tab integer
---@field result_buf integer
---@field result_win integer
---@field current_buf integer
---@field current_win integer
---@field incoming_buf integer
---@field incoming_win integer
---@field active_hunk ConflictHunk?

---@type MergeEditorState
local merge_editor = {
  enabled = false,
  tab = 0,
  result_buf = 0,
  result_win = 0,
  current_buf = 0,
  current_win = 0,
  incoming_buf = 0,
  incoming_win = 0,
  hunks = {},
  active_hunk = nil,
}

local function set_preview_buf_options(bufnr)
  vim.bo[bufnr].buftype = "nofile"
  vim.bo[bufnr].bufhidden = "wipe"
  vim.bo[bufnr].swapfile = false
end

---@param bufnr integer
---@param lnum integer
function M.open_merge_editor(bufnr, lnum)
  if not state.hunks[bufnr] or #state.hunks[bufnr] == 0 then
    return
  end

  local hunk = utils.hunk_from_lnum(bufnr, lnum)
  if not hunk then
    hunk = state.hunks[bufnr][1]
  end

  vim.cmd("tabnew")
  local tab = vim.api.nvim_get_current_tabpage()
  vim.api.nvim_set_current_buf(bufnr)
  local result_win = vim.api.nvim_get_current_win()
  vim.cmd("diffthis")

  vim.cmd("top new")
  local current_change_buf = vim.api.nvim_get_current_buf()
  local current_win = vim.api.nvim_get_current_win()
  vim.cmd("diffthis")
  set_preview_buf_options(current_change_buf)
  vim.bo[current_change_buf].ft = vim.bo[bufnr].ft

  vim.cmd("vnew")
  local incoming_change_buf = vim.api.nvim_get_current_buf()
  local incoming_win = vim.api.nvim_get_current_win()
  vim.cmd("diffthis")
  set_preview_buf_options(incoming_change_buf)
  vim.bo[incoming_change_buf].ft = vim.bo[bufnr].ft

  vim.api.nvim_set_current_win(result_win)

  merge_editor = {
    enabled = true,
    tab = tab,
    result_buf = bufnr,
    result_win = result_win,
    current_buf = current_change_buf,
    current_win = current_win,
    incoming_buf = incoming_change_buf,
    incoming_win = incoming_win,
    hunks = state.hunks[bufnr],
    active_hunk = hunk,
  }

  local all_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  local start_line = hunk.current.line

  local current_change_lines = (
    hunk.base and hunk.base.line or hunk.separator.line
  )
    - hunk.current.line
    - 1
  vim.api.nvim_buf_set_lines(current_change_buf, 0, -1, false, all_lines)
  utils.accept_hunk(current_change_buf, hunk, "current")
  vim.api.nvim_buf_set_extmark(current_change_buf, ns, start_line - 1, 0, {
    virt_lines = { { { "Current Change", hl.groups.annotation } } },
    virt_lines_above = true,
  })
  vim.api.nvim_buf_set_extmark(current_change_buf, ns, start_line - 1, 0, {
    end_line = start_line + current_change_lines - 1,
    hl_group = hl.groups.current,
    hl_eol = true,
  })
  vim.bo[current_change_buf].modifiable = false

  local incoming_change_lines = hunk.incoming.line - hunk.separator.line - 1
  vim.api.nvim_buf_set_lines(incoming_change_buf, 0, -1, false, all_lines)
  utils.accept_hunk(incoming_change_buf, hunk, "incoming")
  vim.api.nvim_buf_set_extmark(incoming_change_buf, ns, start_line - 1, 0, {
    virt_lines = { { { "Incoming Change", hl.groups.annotation } } },
    virt_lines_above = true,
  })
  vim.api.nvim_buf_set_extmark(incoming_change_buf, ns, start_line - 1, 0, {
    end_line = start_line + incoming_change_lines - 1,
    hl_group = hl.groups.incoming,
    hl_eol = true,
  })
  vim.bo[incoming_change_buf].modifiable = false

  vim.api.nvim_win_set_cursor(result_win, { start_line, 0 })
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  if hunk.base then
    local base_change_lines = hunk.separator.line - hunk.base.line - 1
    utils.accept_hunk(bufnr, hunk, "base")
    vim.api.nvim_buf_set_extmark(bufnr, ns, start_line - 1, 0, {
      end_line = start_line + base_change_lines - 1,
      hl_group = hl.groups.current,
      hl_eol = true,
    })
  else
    utils.accept_hunk(bufnr, hunk, "current")
    vim.api.nvim_buf_set_extmark(bufnr, ns, start_line - 1, 0, {
      end_line = start_line + current_change_lines - 1,
      hl_group = hl.groups.current,
      hl_eol = true,
    })
  end
end

function M.close_merge_editor()
  if not merge_editor.enabled then
    return
  end
  merge_editor.enabled = false
  if vim.api.nvim_tabpage_is_valid(merge_editor.tab) then
    vim.api.nvim_set_current_tabpage(merge_editor.tab)
    vim.cmd("tabclose!")
  end
  local hunks = conflict.detect_conflicts(merge_editor.result_buf)
  conflict.highlight_conflicts(merge_editor.result_buf, hunks)
end

function M.setup()
  local augroup =
    vim.api.nvim_create_augroup("UnclashMergeEditor", { clear = true })

  vim.api.nvim_create_autocmd("WinClosed", {
    group = augroup,
    desc = "Disable merge editor when any of its windows is closed",
    callback = function(args)
      if not merge_editor.enabled then
        return
      end
      local closed_win = tonumber(args.match)
      if
        closed_win == merge_editor.result_win
        or closed_win == merge_editor.current_win
        or closed_win == merge_editor.incoming_win
      then
        M.close_merge_editor()
      end
    end,
  })

  vim.api.nvim_create_autocmd("TabClosed", {
    group = augroup,
    desc = "Disable merge editor when tab is closed",
    callback = function(args)
      if not merge_editor.enabled then
        return
      end
      local closed_tab = tonumber(args.match)
      if closed_tab == vim.api.nvim_tabpage_get_number(merge_editor.tab) then
        merge_editor.enabled = false
        local hunks = conflict.detect_conflicts(merge_editor.result_buf)
        conflict.highlight_conflicts(merge_editor.result_buf, hunks)
      end
    end,
  })
end

function M.is_active()
  return merge_editor.enabled
end

return M
