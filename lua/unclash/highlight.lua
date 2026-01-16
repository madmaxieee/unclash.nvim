---@class UnclashHlGroups
---@field current string
---@field current_marker string
---@field base string
---@field base_marker string
---@field incoming string
---@field incoming_marker string
---@field separator string
---@field action_line string
---@field action_button string

local M = {
  ---@type UnclashHlGroups
  groups = {
    current = "UnclashCurrent",
    current_marker = "UnclashCurrentMarker",
    base = "UnclashBase",
    base_marker = "UnclashBaseMarker",
    incoming = "UnclashIncoming",
    incoming_marker = "UnclashIncomingMarker",
    separator = "UnclashSeparator",
    action_line = "UnclashActionLine",
    action_button = "UnclashActionButton",
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

local default_colors = {
  current = { bg = "#2A4556" },
  base = { bg = "#394B70" },
  incoming = { bg = "#4B2A3D" },
  separator = { bg = "#333333" },
  action_line = { bg = "#252A3F" },
  action_button = { fg = "#636da6", bg = "#252A3F", underline = true },
}

local function setup_hl_groups()
  for group, color in pairs(default_colors) do
    local hl_group = M.groups[group]
    vim.api.nvim_set_hl(0, hl_group, color)
    if group == "current" or group == "base" or group == "incoming" then
      local marker_bg = blend_bg(color.bg, 0.4)
      vim.api.nvim_set_hl(0, hl_group .. "Marker", { bg = marker_bg })
    end
  end
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
