local unclash = require("unclash")
local state = require("unclash.state")
local hl = require("unclash.highlight")
local action_line = require("unclash.action_line")
local conflict = require("unclash.conflict")
local merge_editor = require("unclash.merge_editor")

---@param bufnr number
---@return boolean
local function should_detect(bufnr)
  if merge_editor.is_active() then
    return false
  end
  -- skip for large files
  local max_filesize = 1024 * 1024 -- 1MB
  local path = vim.api.nvim_buf_get_name(bufnr)
  local stat = vim.uv.fs_stat(path)
  if stat and stat.size > max_filesize then
    return false
  end
  return true
end

local augroup = vim.api.nvim_create_augroup("Unclash", { clear = true })

vim.api.nvim_create_autocmd("BufReadPost", {
  group = augroup,
  desc = "Apply highlighting to conflicted files",
  callback = function(args)
    if should_detect(args.buf) then
      local hunks = conflict.detect_conflicts(args.buf)
      conflict.highlight_conflicts(args.buf, hunks)
    end
  end,
})

local timers = {}

vim.api.nvim_create_autocmd("TextChanged", {
  group = augroup,
  desc = "Apply highlighting to conflicted files",
  callback = function(args)
    if should_detect(args.buf) then
      if timers[args.buf] then
        timers[args.buf]:stop()
        timers[args.buf]:close()
      end
      timers[args.buf] = vim.defer_fn(function()
        timers[args.buf] = nil
        local hunks = conflict.detect_conflicts(args.buf)
        conflict.highlight_conflicts(args.buf, hunks)
      end, 200)
    end
  end,
})

vim.api.nvim_create_autocmd("BufWipeout", {
  group = augroup,
  desc = "Clean up state for wiped buffers",
  callback = function(args)
    if timers[args.buf] then
      timers[args.buf]:stop()
      timers[args.buf]:close()
      timers[args.buf] = nil
    end
    state.hunks[args.buf] = nil
  end,
})

vim.api.nvim_create_user_command("UnclashAcceptCurrent", function()
  unclash.accept_current()
end, {
  desc = "Accept current changes in the conflict hunk under the cursor",
  nargs = 0,
})

vim.api.nvim_create_user_command("UnclashAcceptIncoming", function()
  unclash.accept_incoming()
end, {
  desc = "Accept incoming changes in the conflict hunk under the cursor",
  nargs = 0,
})

vim.api.nvim_create_user_command("UnclashAcceptBoth", function()
  unclash.accept_both()
end, {
  desc = "Accept both changes in the conflict hunk under the cursor",
  nargs = 0,
})

vim.api.nvim_create_user_command("UnclashScan", function()
  unclash.scan()
end, {
  desc = "Force rescan cwd for conflicted files, may be slow on large repos",
  nargs = 0,
})

vim.api.nvim_create_user_command("UnclashQf", function()
  unclash.scan(function()
    unclash.set_qflist()
    vim.cmd("copen")
  end)
end, {
  desc = "Set the quickfix list with all conflicts",
  nargs = 0,
})

vim.api.nvim_create_user_command("UnclashTrouble", function()
  unclash.scan(function()
    unclash.set_qflist()
    vim.cmd("Trouble qflist")
  end)
end, {
  desc = "Set the quickfix list with all conflicts",
  nargs = 0,
})

vim.api.nvim_create_user_command("UnclashOpenMergeEditor", function()
  unclash.open_merge_editor()
end, {
  desc = "Open the merge editor for the current conflicted file",
  nargs = 0,
})

hl.setup()
action_line.setup()
merge_editor.setup()
