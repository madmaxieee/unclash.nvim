local M = {}

local constants = require("unclash.constant")

---@return snacks.picker.Item[]
local function unclash_conflict_finder()
  local res = vim
    .system({
      "rg",
      "--vimgrep",
      ([[^%s\s]]):format(constants.CURRENT_MARKER),
    })
    :wait()

  if res.code ~= 0 then
    return {}
  end

  ---@type snacks.picker.Item[]
  local results = {}

  for line in res.stdout:gmatch("[^\n]+") do
    local file, lnum, col, text = line:match("^(.-):(%d+):(%d+):(.+)")
    assert(
      file and lnum and col and text,
      "Failed to parse rg output: " .. line
    )
    results[#results + 1] = {
      idx = #results + 1,
      file = file,
      pos = { tonumber(lnum), tonumber(col) },
      text = text,
      score = 0,
    }
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
