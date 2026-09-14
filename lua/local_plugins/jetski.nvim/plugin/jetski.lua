-- plugin/jetski.lua - User commands and auto-registration for jetski.nvim
if vim.g.loaded_jetski_nvim then
  return
end
vim.g.loaded_jetski_nvim = true

local jetski = require("jetski")

-- Core panel & session commands
vim.api.nvim_create_user_command("Jetski", function(opts)
  if opts.args ~= "" then
    jetski.open({ prompt = opts.args })
  else
    jetski.toggle()
  end
end, { nargs = "*", desc = "Open or toggle Jetski panel, optionally with initial prompt" })

vim.api.nvim_create_user_command("JetskiToggle", function()
  jetski.toggle()
end, { desc = "Toggle Jetski panel visibility" })

vim.api.nvim_create_user_command("JetskiNew", function(opts)
  jetski.new_session(opts.args ~= "" and opts.args or nil)
end, { nargs = "*", desc = "Start a new Jetski session" })

vim.api.nvim_create_user_command("JetskiContinue", function(opts)
  jetski.continue_session(opts.args ~= "" and opts.args or nil)
end, { nargs = "*", desc = "Continue the last Jetski session" })

vim.api.nvim_create_user_command("JetskiKill", function()
  jetski.kill()
end, { desc = "Kill active Jetski process and wipe terminal buffer" })

vim.api.nvim_create_user_command("JetskiStatus", function()
  jetski.status()
end, { desc = "Show Jetski integration status and configuration" })

vim.api.nvim_create_user_command("JetskiPreload", function()
  jetski.preload()
end, { desc = "Preload Jetski in a hidden background buffer" })

-- Context actions
vim.api.nvim_create_user_command("JetskiAsk", function(opts)
  jetski.ask(opts.args ~= "" and opts.args or nil)
end, { nargs = "*", range = true, desc = "Ask Jetski a question with attached buffer or selection context" })

vim.api.nvim_create_user_command("JetskiExplain", function()
  jetski.explain()
end, { range = true, desc = "Explain current visual selection or code" })

vim.api.nvim_create_user_command("JetskiRefactor", function(opts)
  jetski.refactor(opts.args ~= "" and opts.args or nil)
end, { nargs = "*", range = true, desc = "Refactor current visual selection or code" })

vim.api.nvim_create_user_command("JetskiFix", function(opts)
  local line_only = opts.bang or (opts.args == "line")
  jetski.fix(line_only)
end, { bang = true, nargs = "?", desc = "Fix diagnostics/compiler errors (use ! or 'line' for cursor line only)" })

vim.api.nvim_create_user_command("JetskiTest", function()
  jetski.test()
end, { range = true, desc = "Generate unit tests for selection or function" })

-- Comments and code review
vim.api.nvim_create_user_command("JetskiComment", function()
  jetski.comments.add_comment()
end, { range = true, desc = "Add or edit comment on current line or range" })

vim.api.nvim_create_user_command("JetskiCommentDelete", function()
  jetski.comments.delete_comment()
end, { desc = "Delete comment on current line" })

vim.api.nvim_create_user_command("JetskiCommentList", function()
  jetski.comments.list_comments()
end, { desc = "List all pending comments in quickfix" })

vim.api.nvim_create_user_command("JetskiCommentSubmit", function()
  jetski.comments.submit_all_comments()
end, { desc = "Submit all pending comments to Jetski" })

vim.api.nvim_create_user_command("JetskiCommentClear", function()
  jetski.comments.clear_all_comments()
end, { desc = "Clear all pending comments and signs" })

-- Diff review & resolution
local function complete_diff_files(arg_lead)
  local ok, diff = pcall(require, "jetski.diff")
  if ok and diff.complete_diff_files then
    return diff.complete_diff_files(arg_lead)
  end
  return vim.fn.getcompletion(arg_lead, "file")
end

vim.api.nvim_create_user_command("JetskiDiff", function(opts)
  jetski.diff_review(opts.args ~= "" and opts.args or nil)
end, { nargs = "?", complete = complete_diff_files, desc = "Review diff between pre-edit snapshot and current file" })

vim.api.nvim_create_user_command("JetskiDiffReview", function(opts)
  jetski.diff_review(opts.args ~= "" and opts.args or nil)
end, { nargs = "?", complete = complete_diff_files, desc = "Review diff between pre-edit snapshot and current file" })

vim.api.nvim_create_user_command("JetskiAccept", function(opts)
  jetski.diff_accept(opts.args ~= "" and opts.args or nil)
end, { nargs = "?", complete = complete_diff_files, desc = "Accept all agent edits for the file" })

vim.api.nvim_create_user_command("JetskiDiffAccept", function(opts)
  jetski.diff_accept(opts.args ~= "" and opts.args or nil)
end, { nargs = "?", complete = complete_diff_files, desc = "Accept all agent edits for the file" })

vim.api.nvim_create_user_command("JetskiReject", function(opts)
  jetski.diff_reject(opts.args ~= "" and opts.args or nil)
end, { nargs = "?", complete = complete_diff_files, desc = "Reject all agent edits and revert to pre-edit state" })

vim.api.nvim_create_user_command("JetskiDiffReject", function(opts)
  jetski.diff_reject(opts.args ~= "" and opts.args or nil)
end, { nargs = "?", complete = complete_diff_files, desc = "Reject all agent edits and revert to pre-edit state" })

vim.api.nvim_create_user_command("JetskiCloseDiff", function()
  jetski.diff_close()
end, { desc = "Close active Jetski diff review" })

vim.api.nvim_create_user_command("JetskiDiffClose", function()
  jetski.diff_close()
end, { desc = "Close active Jetski diff review" })

-- Artifacts & Plans
vim.api.nvim_create_user_command("JetskiPlan", function(opts)
  jetski.open_plan(opts.args ~= "" and opts.args or nil)
end, { nargs = "?", complete = "file", desc = "Open implementation plan" })

vim.api.nvim_create_user_command("JetskiWalkthrough", function(opts)
  jetski.open_walkthrough(opts.args ~= "" and opts.args or nil)
end, { nargs = "?", complete = "file", desc = "Open walkthrough" })

vim.api.nvim_create_user_command("JetskiArtifacts", function()
  jetski.list_artifacts()
end, { desc = "Browse and open session artifacts" })

-- Skill and RPC helpers
vim.api.nvim_create_user_command("JetskiUpdateSkill", function()
  jetski.update_skill()
end, { desc = "Install/update companion SKILL.md for Jetski" })

vim.api.nvim_create_user_command("JetskiOpenFile", function(opts)
  local args = vim.split(opts.args, "%s+")
  local file = args[1]
  local line = args[2] and tonumber(args[2]) or nil
  local col = args[3] and tonumber(args[3]) or nil
  jetski.open_file(file, line, col)
end, { nargs = "+", complete = "file", desc = "Open file in editor window (RPC helper)" })
