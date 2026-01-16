local M = {}

local state = require("unclash.state")
local ns = require("unclash.constant").ns
local hl = require("unclash.highlight")
local action_line = require("unclash.action_line")

local CURRENT_MARKER = "<<<<<<<"
local BASE_MARKER = "|||||||"
local SEPARATOR_MARKER = "======="
local INCOMING_MARKER = ">>>>>>>"

---@alias MarkerType "current" | "base" | "separator" | "incoming"

---@class Marker
---@field line integer
---@field type MarkerType

---@class MarkerSet
---@field current Marker[]
---@field base Marker[]
---@field separator Marker[]
---@field incoming Marker[]

---@param path string a directory or a single file
---@return table<string, boolean> conflicted files
local function detect_conflicted_files(path)
  local jobs = {
    vim.system({ "rg", "-l", "^<{7}", path }),
    vim.system({ "rg", "-l", "^={7}", path }),
    vim.system({ "rg", "-l", "^>{7}", path }),
  }

  local job_results = {}
  for i, job in ipairs(jobs) do
    job_results[i] = job:wait()
  end

  for _, result in pairs(job_results) do
    -- code 0 indicates a match was found
    if result.code ~= 0 then
      return {}
    end
  end

  local candidate_files = {}
  for _, result in ipairs(job_results) do
    for line in vim.gsplit(result.stdout, "\n") do
      if line ~= "" then
        candidate_files[line] = (candidate_files[line] or 0) + 1
      end
    end
  end

  local conflicted_files = {}
  for file, count in pairs(candidate_files) do
    if count == #jobs then
      conflicted_files[file] = true
    end
  end

  return conflicted_files
end

---@param bufnr integer
---@return MarkerSet
local function find_markers(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  ---@type MarkerSet
  local markers = {
    current = {},
    separator = {},
    base = {},
    incoming = {},
  }
  for i, line in ipairs(lines) do
    if vim.startswith(line, CURRENT_MARKER) then
      markers.current[#markers.current + 1] = {
        line = i,
        type = "current",
      }
    elseif vim.startswith(line, BASE_MARKER) then
      markers.base[#markers.base + 1] = {
        line = i,
        type = "base",
      }
    elseif vim.startswith(line, SEPARATOR_MARKER) then
      markers.separator[#markers.separator + 1] = {
        line = i,
        type = "separator",
      }
    elseif vim.startswith(line, INCOMING_MARKER) then
      markers.incoming[#markers.incoming + 1] = {
        line = i,
        type = "incoming",
      }
    end
  end

  return markers
end

---@param markers MarkerSet
---@param line integer
---@return Marker?
-- Finds the next marker after the given line, also removes all markers before
-- it from the marker set
local function get_next_marker(markers, line)
  ---@type Marker?
  local next_marker = nil
  for _, t in ipairs({ "current", "base", "separator", "incoming" }) do
    if #markers[t] > 0 then
      while #markers[t] > 0 and markers[t][1].line <= line do
        table.remove(markers[t], 1)
      end
      if #markers[t] > 0 then
        if not next_marker or markers[t][1].line < next_marker.line then
          next_marker = markers[t][1]
        end
      end
    end
  end
  return next_marker
end

---@class ConflictHunk
---@field current Marker
---@field base Marker?
---@field separator Marker
---@field incoming Marker

---@param bufnr integer
---@param conflicts ConflictHunk[]
local function highlight_conflicts(bufnr, conflicts)
  -- clear previous extmarks
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  for _, conflict in ipairs(conflicts) do
    action_line.draw_action_line(bufnr, conflict.current.line)
    hl.hl_lines(bufnr, {
      start_line = conflict.current.line,
      end_line = conflict.current.line,
      hl_group = hl.groups.current_marker,
    })
    if conflict.base then
      hl.hl_lines(bufnr, {
        start_line = conflict.current.line + 1,
        end_line = conflict.base.line - 1,
        hl_group = hl.groups.current,
      })
      hl.hl_lines(bufnr, {
        start_line = conflict.base.line,
        end_line = conflict.base.line,
        hl_group = hl.groups.base_marker,
      })
      hl.hl_lines(bufnr, {
        start_line = conflict.base.line + 1,
        end_line = conflict.separator.line - 1,
        hl_group = hl.groups.base,
      })
    else
      hl.hl_lines(bufnr, {
        start_line = conflict.current.line + 1,
        end_line = conflict.separator.line - 1,
        hl_group = hl.groups.current,
      })
    end
    hl.hl_lines(bufnr, {
      start_line = conflict.separator.line + 1,
      end_line = conflict.incoming.line - 1,
      hl_group = hl.groups.incoming,
    })
    hl.hl_lines(bufnr, {
      start_line = conflict.incoming.line,
      end_line = conflict.incoming.line,
      hl_group = hl.groups.incoming_marker,
    })
  end
end

---@param bufnr integer
---@param opts? {force:boolean}
---@return ConflictHunk[]
local function detect_conflicts(bufnr, opts)
  opts = opts or {}

  if not opts.force and not state.conflicted_bufs then
    return {}
  end

  local markers = find_markers(bufnr)

  ---@type ConflictHunk[]
  local hunks = {}

  ---@type Marker?
  local current = nil

  while true do
    local base = nil
    ---@type Marker?
    local separator = nil
    ---@type Marker?
    local incoming = nil

    while not (current and current.type == "current") do
      current = get_next_marker(markers, current and current.line or 0)
      if not current then
        break
      end
    end
    if not current then
      break
    end

    ---@type Marker?
    local next_marker = get_next_marker(markers, current.line)
    if not next_marker then
      break
    end

    if next_marker.type == "current" then
      current = next_marker
      goto continue
    elseif next_marker.type == "base" then
      base = next_marker
    elseif next_marker.type == "separator" then
      separator = next_marker
    elseif next_marker.type == "incoming" then
      current = nil
      goto continue
    end

    if base then
      next_marker = get_next_marker(markers, next_marker.line)
      if not next_marker then
        break
      end
      if next_marker.type == "current" then
        current = next_marker
        goto continue
      elseif next_marker.type == "separator" then
        separator = next_marker
      else
        current = nil
        goto continue
      end
    end

    assert(separator)
    assert(next_marker)

    ---@diagnostic disable-next-line: need-check-nil
    next_marker = get_next_marker(markers, next_marker.line)
    if not next_marker then
      break
    end

    if next_marker.type == "current" then
      current = next_marker
      goto continue
    elseif next_marker.type == "incoming" then
      incoming = next_marker
    else
      current = nil
      goto continue
    end

    assert(current)
    assert(incoming)

    hunks[#hunks + 1] = {
      current = current,
      base = base,
      separator = separator,
      incoming = incoming,
    }

    current = nil
    ::continue::
  end

  state.hunks[bufnr] = hunks
  return hunks
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

function M.setup()
  local augroup =
    vim.api.nvim_create_augroup("ConflictDetection", { clear = true })

  vim.api.nvim_create_autocmd(
    { "VimEnter", "FileChangedShellPost", "DirChanged" },
    {
      group = augroup,
      desc = "Detect conflicted files in the current working directory on startup",
      callback = function()
        state.conflicted_files = detect_conflicted_files(vim.fn.getcwd())
      end,
    }
  )

  vim.api.nvim_create_autocmd("BufReadPre", {
    group = augroup,
    desc = "Detect if the opened file is conflicted",
    callback = function(args)
      local file = vim.api.nvim_buf_get_name(args.buf)
      if state.conflicted_files[file] then
        state.conflicted_bufs[args.buf] = true
      end
    end,
  })

  vim.api.nvim_create_autocmd({ "BufRead", "TextChanged" }, {
    group = augroup,
    desc = "Apply highlighting to conflicted files",
    callback = function(args)
      local hunks = detect_conflicts(args.buf)
      highlight_conflicts(args.buf, hunks)
    end,
  })

  hl.setup()
  action_line.setup()
end

return M

-- TODO: add accept action api for keymap and commands
-- TODO: read from predefined DiffAdd colors
-- TODO: add snakcs picker to find conflict location
-- TODO: write readme
-- TODO: show warning if rg is not present?
-- TODO: use in-process LSP to provide code actions for resolving conflicts?
-- TODO: implement vscode-like merge editor
