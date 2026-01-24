local M = {}

---@class unclash.Config
---@field action_buttons {enabled: boolean} Configuration for action buttons
---@field annotations {enabled: boolean} Configuration for annotations

---@class unclash.PartialConfig
---@field action_buttons? {enabled: boolean} Configuration for action buttons
---@field annotations? {enabled: boolean} Configuration for annotations

---@type unclash.Config
local config = {
  action_buttons = {
    enabled = true,
  },
  annotations = {
    enabled = true,
  },
}

function M.get()
  return config
end

function M.set(new_config)
  config = vim.tbl_deep_extend("force", config, new_config)
end

return M
