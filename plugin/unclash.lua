local unclash = require("unclash")
local state = require("unclash.state")
local hl = require("unclash.highlight")
local action_line = require("unclash.action_line")
local conflict = require("unclash.conflict")
local merge_editor = require("unclash.merge_editor")

local augroup = vim.api.nvim_create_augroup("Unclash", { clear = true })

vim.api.nvim_create_autocmd(
  { "VimEnter", "FileChangedShellPost", "DirChanged", "FocusGained" },
  {
    group = augroup,
    desc = "Detect conflicted files in the current working directory on startup",
    callback = function()
      unclash.refresh({ silent = true })
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

local timers = {}

vim.api.nvim_create_autocmd({ "BufRead", "TextChanged" }, {
  group = augroup,
  desc = "Apply highlighting to conflicted files",
  callback = function(args)
    if merge_editor.is_active() then
      return
    end
    if state.conflicted_bufs[args.buf] then
      if timers[args.buf] then
        timers[args.buf]:stop()
        timers[args.buf]:close()
      end
      timers[args.buf] = vim.defer_fn(function()
        timers[args.buf] = nil
        if vim.api.nvim_buf_is_valid(args.buf) then
          local hunks = conflict.detect_conflicts(args.buf)
          state.hunks[args.buf] = hunks
          conflict.highlight_conflicts(args.buf, hunks)
        end
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
    state.conflicted_bufs[args.buf] = nil
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

vim.api.nvim_create_user_command("UnclashRefresh", function()
  unclash.refresh()
end, {
  desc = "Force refresh of conflicted files status",
  nargs = 0,
})

vim.api.nvim_create_user_command("UnclashQf", function()
  unclash.set_qflist()
  vim.cmd("copen")
end, {
  desc = "Set the quickfix list with all conflicts",
  nargs = 0,
})

vim.api.nvim_create_user_command("UnclashTrouble", function()
  unclash.set_qflist()
  vim.cmd("Trouble qflist")
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
