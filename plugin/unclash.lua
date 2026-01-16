local unclash = require("unclash")
local state = require("unclash.state")
local hl = require("unclash.highlight")
local action_line = require("unclash.action_line")
local conflict = require("unclash.conflict")

local augroup = vim.api.nvim_create_augroup("Unclash", { clear = true })

vim.api.nvim_create_autocmd(
  { "VimEnter", "FileChangedShellPost", "DirChanged" },
  {
    group = augroup,
    desc = "Detect conflicted files in the current working directory on startup",
    callback = function()
      state.conflicted_files = conflict.detect_conflicted_files(vim.fn.getcwd())
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
    if state.conflicted_bufs[args.buf] then
      local hunks = conflict.detect_conflicts(args.buf)
      conflict.highlight_conflicts(args.buf, hunks)
    end
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

vim.api.nvim_create_user_command("UnclashAcceptNone", function()
  unclash.accept_none()
end, {
  desc = "Accept none of the changes in the conflict hunk under the cursor",
  nargs = 0,
})

hl.setup()
action_line.setup()
