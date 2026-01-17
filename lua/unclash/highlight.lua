---@class UnclashHlGroups
---@field current string
---@field current_marker string
---@field base string
---@field base_marker string
---@field incoming string
---@field incoming_marker string
---@field action_line string
---@field action_button string
---@field merge_editor_button string
---@field annotation string

local M = {
  ---@type UnclashHlGroups
  groups = {
    current = "UnclashCurrent",
    current_marker = "UnclashCurrentMarker",
    base = "UnclashBase",
    base_marker = "UnclashBaseMarker",
    incoming = "UnclashIncoming",
    incoming_marker = "UnclashIncomingMarker",
    action_line = "UnclashActionLine",
    action_button = "UnclashActionButton",
    merge_editor_button = "UnclashMergeEditorButton",
    annotation = "UnclashAnnotation",
  },
}

local ns = require("unclash.constant").ns

---@alias RGB [number, number, number]

---@param c  string|number
---@return RGB
local function rgb(c)
  if type(c) == "number" then
    return { c / (256 ^ 2), (c % (256 ^ 2)) / 256, c % 256 }
  else
    c = string.lower(c)
    return {
      tonumber(c:sub(2, 3), 16),
      tonumber(c:sub(4, 5), 16),
      tonumber(c:sub(6, 7), 16),
    }
  end
end

---@param color1 string|number
---@param color2 string|number
---@param alpha number number between 0 and 1. 0 results in color1, 1 results in color2
local function blend(color1, alpha, color2)
  local bg = rgb(color2)
  local fg = rgb(color1)

  local blend_channel = function(i)
    local ret = (alpha * fg[i] + ((1 - alpha) * bg[i]))
    return math.floor(math.min(math.max(0, ret), 255) + 0.5)
  end

  return string.format(
    "#%02x%02x%02x",
    blend_channel(1),
    blend_channel(2),
    blend_channel(3)
  )
end

local function blend_bg(color, amount)
  local normal = vim.api.nvim_get_hl(0, { name = "Normal" })
  local bg = normal.bg and normal.bg or "#000000"
  return blend(color, amount, bg)
end

local function blend_fg(color, amount)
  local normal = vim.api.nvim_get_hl(0, { name = "Normal" })
  local fg = normal.fg and normal.fg or "#ffffff"
  return blend(color, amount, fg)
end

local hl_links = {
  current = "DiffAdd",
  base = "DiffChange",
  incoming = "DiffText",
  action_line = "DiffChange",
  annotation = "NonText",
}

local function setup_hl_groups()
  for group, link in pairs(hl_links) do
    local hl_group = M.groups[group]
    vim.api.nvim_set_hl(0, hl_group, { link = link })
    if group == "current" or group == "base" or group == "incoming" then
      local c = vim.api.nvim_get_hl(0, { name = link })
      local marker_bg = blend_bg(c.bg, 0.4)
      vim.api.nvim_set_hl(0, hl_group .. "Marker", { bg = marker_bg })
    end
  end

  local comment_fg = vim.api.nvim_get_hl(0, { name = "Comment" }).fg
  local diff_change_bg = vim.api.nvim_get_hl(0, { name = "DiffChange" }).bg
  vim.api.nvim_set_hl(0, M.groups.action_button, {
    fg = comment_fg,
    bg = diff_change_bg,
    underline = true,
  })
  vim.api.nvim_set_hl(0, M.groups.merge_editor_button, {
    fg = blend_fg(comment_fg, 0.5),
    bg = diff_change_bg,
    underline = true,
    bold = true,
  })
end

function M.setup()
  setup_hl_groups()
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("UnclashHighlight", { clear = true }),
    desc = "update colors",
    callback = function()
      setup_hl_groups()
    end,
  })
end

---@class HighlightRange
---@field start_line integer 1-based indexing, inclusive
---@field end_line integer
---@field hl_group string

---@param bufnr integer
---@param range HighlightRange
function M.hl_lines(bufnr, range)
  vim.api.nvim_buf_set_extmark(bufnr, ns, range.start_line - 1, 0, {
    end_line = range.end_line,
    hl_group = range.hl_group,
    hl_eol = true,
  })
end

return M
