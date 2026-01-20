local M = {}

local hl = require("unclash.highlight")
local state = require("unclash.state")

local ns = require("unclash.constant").ns

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

local has_rg = vim.fn.executable("rg") == 1
local TIMEOUT = 3000

---@param path string a directory or a single file
---@param on_done fun(files: table<string, boolean>)
---@param opts? {silent?: boolean}
---@return nil
function M.scan_maybe_conflicted_files(path, on_done, opts)
  opts = opts or {}

  local cmd
  if has_rg then
    cmd = { "rg", "-l", "^<{7}", path }
  else
    cmd = { "grep", "-rl", "^<<<<<<<", path }
  end

  vim.system(cmd, { timeout = TIMEOUT }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        if not opts.silent then
          -- SIGTERM or SIGKILL
          if result.signal == 15 or result.signal == 9 then
            vim.notify(
              "Unclash: Scanning for conflicted files timed out",
              vim.log.levels.WARN
            )
          elseif result.code > 1 then
            vim.notify(
              "Unclash: Error scanning for conflicted files: "
                .. (result.stderr or "unknown error"),
              vim.log.levels.ERROR
            )
          end
        end
        on_done({})
        return
      end

      local candidate_files = {}
      for line in vim.gsplit(result.stdout, "\n") do
        if line ~= "" then
          candidate_files[line] = true
        end
      end

      on_done(candidate_files)
    end)
  end)
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
---@param conflicts ConflictHunk[]?
function M.highlight_conflicts(bufnr, conflicts)
  if not conflicts then
    vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
    return
  end

  -- clear previous extmarks
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  for _, conflict in ipairs(conflicts) do
    require("unclash.action_line").draw_action_line(
      bufnr,
      conflict.current.line
    )
    vim.api.nvim_buf_set_extmark(bufnr, ns, conflict.current.line - 1, 0, {
      virt_text = { { "(Current Change)", hl.groups.annotation } },
      virt_text_pos = "eol",
      right_gravity = false,
      hl_mode = "combine",
    })
    vim.api.nvim_buf_set_extmark(bufnr, ns, conflict.incoming.line - 1, 0, {
      virt_text = { { "(Incoming Change)", hl.groups.annotation } },
      virt_text_pos = "eol",
      right_gravity = false,
      hl_mode = "combine",
    })
    if conflict.base then
      vim.api.nvim_buf_set_extmark(bufnr, ns, conflict.base.line - 1, 0, {
        virt_text = { { "(Base)", hl.groups.annotation } },
        virt_text_pos = "eol",
        right_gravity = false,
        hl_mode = "combine",
      })
    end
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
---@return ConflictHunk[]?
function M.detect_conflicts(bufnr)
  local markers = find_markers(bufnr)
  if
    #markers.current == 0
    or #markers.separator == 0
    or #markers.incoming == 0
  then
    return nil
  end

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

  if #hunks > 0 then
    state.hunks[bufnr] = hunks
    return hunks
  else
    state.hunks[bufnr] = nil
    return nil
  end
end

return M
