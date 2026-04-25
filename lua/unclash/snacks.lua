local M = {}

local constants = require("unclash.constant")
local conflict = require("unclash.conflict")

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
    local lines = vim.fn.readfile(file)
    local markers = conflict.find_markers(lines)
    local hunks = conflict.build_hunks(markers)
    for _, hunk in ipairs(hunks) do
      results[#results + 1] = {
        idx = #results + 1,
        file = file,
        pos = { hunk.current.line, 1 },
        text = lines[hunk.current.line],
        score = 0,
      }
    end
  end

  return results
end

function M.pick()
  local picker = require("snacks.picker")
  picker.pick({
    title = "Merge Conflicts",
    finder = unclash_conflict_finder,
    format = "file",
  })
end

return M
