local M = {}

local constants = require("unclash.constant")
local conflict = require("unclash.conflict")
local hl = require("unclash.highlight")

---@return snacks.picker.Item[]
local function unclash_conflict_finder()
  local res = vim
    .system({
      "rg",
      "-l",
      ([[^%s\s]]):format(constants.CURRENT_MARKER),
    })
    :wait()

  if res.code ~= 0 then
    return {}
  end

  ---@type snacks.picker.Item[]
  local results = {}

  for file in res.stdout:gmatch("[^\n]+") do
    local file_bufnr = vim.fn.bufadd(file)
    if not vim.api.nvim_buf_is_loaded(file_bufnr) then
      vim.fn.bufload(file_bufnr)
    end
    local hunks = conflict.detect_conflicts(file_bufnr)
    for _, hunk in ipairs(hunks) do
      results[#results + 1] = {
        idx = #results + 1,
        file = file,
        pos = { hunk.current.line, 1 },
        text = "",
        score = 0,
        hunk = hunk,
      }
    end
  end

  return results
end

---@param ctx snacks.picker.preview.ctx
local function preview_conflict(ctx)
  ctx.preview:reset()

  local file = ctx.item.file
  if not file then
    ctx.preview:notify("no file", "warn")
    return
  end

  local file_bufnr = vim.fn.bufadd(file)
  if not vim.api.nvim_buf_is_loaded(file_bufnr) then
    vim.fn.bufload(file_bufnr)
  end
  local lines = vim.api.nvim_buf_get_lines(file_bufnr, 0, -1, false)

  ctx.preview:set_lines(lines)
  ctx.preview:highlight({ file = file })

  local ns = constants.ns
  vim.api.nvim_buf_clear_namespace(ctx.buf, ns, 0, -1)

  local hunk = ctx.item.hunk
  if hunk then
    hl.hl_lines(ctx.buf, {
      start_line = hunk.current.line,
      end_line = hunk.current.line,
      hl_group = hl.groups.current_marker,
    })
    if hunk.base then
      hl.hl_lines(ctx.buf, {
        start_line = hunk.current.line + 1,
        end_line = hunk.base.line - 1,
        hl_group = hl.groups.current,
      })
      hl.hl_lines(ctx.buf, {
        start_line = hunk.base.line,
        end_line = hunk.base.line,
        hl_group = hl.groups.base_marker,
      })
      hl.hl_lines(ctx.buf, {
        start_line = hunk.base.line + 1,
        end_line = hunk.separator.line - 1,
        hl_group = hl.groups.base,
      })
    else
      hl.hl_lines(ctx.buf, {
        start_line = hunk.current.line + 1,
        end_line = hunk.separator.line - 1,
        hl_group = hl.groups.current,
      })
    end
    hl.hl_lines(ctx.buf, {
      start_line = hunk.separator.line + 1,
      end_line = hunk.incoming.line - 1,
      hl_group = hl.groups.incoming,
    })
    hl.hl_lines(ctx.buf, {
      start_line = hunk.incoming.line,
      end_line = hunk.incoming.line,
      hl_group = hl.groups.incoming_marker,
    })
  end

  ctx.preview:loc()
end

function M.pick()
  local picker = require("snacks.picker")
  picker.pick({
    title = "Merge Conflicts",
    finder = unclash_conflict_finder,
    format = "file",
    preview = preview_conflict,
  })
end

return M
