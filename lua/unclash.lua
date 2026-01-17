local M = {}

local conflict = require("unclash.conflict")
local merge_editor = require("unclash.merge_editor")
local state = require("unclash.state")
local utils = require("unclash.utils")

---@param action "current" | "incoming" | "both"
function M.accept(action)
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local hunks = state.hunks[bufnr]
  if not hunks or #hunks == 0 then
    vim.notify("No conflicts detected in this file", vim.log.levels.INFO)
    return
  end

  local hunk = utils.hunk_from_lnum(bufnr, cursor[1])
  if not hunk then
    vim.notify("Cursor is not within a conflict hunk", vim.log.levels.WARN)
    return
  end

  local ok, err = pcall(function()
    utils.accept_hunk(bufnr, hunk, action)
  end)
  if not ok then
    vim.notify("Failed to accept changes: " .. err, vim.log.levels.ERROR)
  end
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

function M.set_qflist()
  local items = {}
  for file, _ in pairs(state.conflicted_files) do
    local uri = vim.uri_from_fname(file)
    local bufnr = vim.uri_to_bufnr(uri)
    if not vim.api.nvim_buf_is_loaded(bufnr) then
      vim.fn.bufload(bufnr)
    end
    if not (state.hunks[bufnr] and #state.hunks[bufnr] > 0) then
      state.hunks[bufnr] = conflict.detect_conflicts(bufnr)
    end
    for _, hunk in ipairs(state.hunks[bufnr]) do
      table.insert(items, {
        filename = file,
        lnum = hunk.current.line,
        end_lnum = hunk.incoming.line,
        text = "Conflict detected",
      })
    end
  end
  vim.fn.setqflist({}, " ", {
    title = "Unclash Conflicts",
    items = items,
  })
end

function M.open_merge_editor()
  local bufnr = vim.api.nvim_get_current_buf()
  if not state.conflicted_bufs[bufnr] then
    vim.notify("Current buffer is not a conflicted file", vim.log.levels.WARN)
    return
  end
  local cursor = vim.api.nvim_win_get_cursor(0)
  merge_editor.open_merge_editor(bufnr, cursor[1])
end

---@param opts? {silent?: boolean}
function M.refresh(opts)
  opts = opts or {}
  state.conflicted_files = conflict.detect_conflicted_files(vim.fn.getcwd())

  -- Update status for all loaded buffers
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) then
      local file = vim.api.nvim_buf_get_name(bufnr)
      if state.conflicted_files[file] then
        state.conflicted_bufs[bufnr] = true
        -- Trigger highlight update
        local hunks = conflict.detect_conflicts(bufnr)
        state.hunks[bufnr] = hunks
        conflict.highlight_conflicts(bufnr, hunks)
      else
        -- Cleanup if it was conflicted but no longer is
        if state.conflicted_bufs[bufnr] then
          state.conflicted_bufs[bufnr] = nil
          state.hunks[bufnr] = nil
          conflict.highlight_conflicts(bufnr, {})
        end
      end
    end
  end
  if not opts.silent then
    vim.notify("Unclash: Refreshed conflict status", vim.log.levels.INFO)
  end
end

return M
