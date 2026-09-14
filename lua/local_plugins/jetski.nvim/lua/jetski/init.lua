--- Main entry point and public API for jetski.nvim
local config = require("jetski.config")
local terminal = require("jetski.terminal")
local context = require("jetski.context")
local comments = require("jetski.comments")
local diff = require("jetski.diff")
local artifacts = require("jetski.artifacts")
local skill = require("jetski.skill")
local workspace = require("jetski.workspace")

local M = {}

--- Re-export submodules for advanced programmatic extension
M.config = config
M.terminal = terminal
M.context = context
M.comments = comments
M.diff = diff
M.artifacts = artifacts
M.skill = skill
M.workspace = workspace

--- Initializes the plugin with optional user configuration.
---@param opts? table User options table
function M.setup(opts)
  local cfg = config.setup(opts)

  -- Initialize comments highlights and indicators
  comments.setup_highlights()

  -- Initialize auto-revert file watchers
  diff.setup_autoread()

  -- Check and install companion skill if needed
  vim.schedule(function()
    skill.check_skill_installed()
  end)

  -- Register default keymaps if enabled
  if cfg.enable_default_keymaps then
    M.setup_keymaps()
  end

  -- Preload Jetski CLI in background buffer if enabled and not in headless mode
  if cfg.preload then
    local function do_preload()
      if #vim.api.nvim_list_uis() > 0 then
        M.preload()
      end
    end

    if vim.v.vim_did_enter == 1 then
      vim.schedule(do_preload)
    else
      vim.api.nvim_create_autocmd("VimEnter", {
        once = true,
        callback = do_preload,
      })
    end
  end

  -- Automatically kill Jetski process and wipe buffer when Neovim exits
  if cfg.kill_on_exit then
    vim.api.nvim_create_autocmd("VimLeavePre", {
      group = vim.api.nvim_create_augroup("JetskiExitCleanup", { clear = true }),
      callback = function()
        terminal.kill(true)
      end,
    })
  end
end

--- Registers keymaps based on configuration.
function M.setup_keymaps()
  local km = config.get().keymaps
  if not km then return end

  local function bind(mode, lhs, rhs, desc)
    if lhs and lhs ~= "" then
      vim.keymap.set(mode, lhs, rhs, { silent = true, desc = desc })
    end
  end

  -- Session & Panel controls
  bind("n", km.toggle, function() M.toggle() end, "Toggle Jetski panel")
  bind("n", km.new_session, function() M.new_session() end, "New Jetski session")
  bind("n", km.continue_session, function() M.continue_session() end, "Continue Jetski session")

  -- Context actions
  bind("n", km.ask, function() M.ask() end, "Ask Jetski (with file context)")
  bind("v", km.ask, function() M.ask() end, "Ask Jetski (with selection context)")
  bind({ "n", "v" }, km.explain, function() M.explain() end, "Explain code with Jetski")
  bind({ "n", "v" }, km.refactor, function() M.refactor() end, "Refactor code with Jetski")
  bind("n", km.fix, function() M.fix() end, "Fix diagnostics with Jetski")
  bind({ "n", "v" }, km.test, function() M.test() end, "Generate tests with Jetski")

  -- Comments and code review
  bind("n", km.comment, function() comments.add_comment() end, "Add/edit Jetski comment")
  bind("v", km.comment, function() comments.add_visual_comment() end, "Add Jetski comment on selection")
  bind("n", km.comment_delete, function() comments.delete_comment() end, "Delete Jetski comment")
  bind("n", km.comment_list, function() comments.list_comments() end, "List pending Jetski comments")
  bind("n", km.comment_submit, function() comments.submit_all_comments() end, "Submit comments to Jetski")
  bind("n", km.comment_clear, function() comments.clear_all_comments() end, "Clear all Jetski comments")

  -- Diff review & resolution
  bind("n", km.diff_review, function() diff.review_diff() end, "Review Jetski diff")
  bind("n", km.diff_accept, function() diff.accept_diff() end, "Accept Jetski diff edits")
  bind("n", km.diff_reject, function() diff.reject_diff() end, "Reject Jetski diff edits")
  bind("n", km.diff_close, function() diff.close_diff_review() end, "Close Jetski diff review")

  -- Artifacts & Plans
  bind("n", km.open_plan, function() artifacts.open_plan() end, "Open Jetski implementation plan")
  bind("n", km.open_walkthrough, function() artifacts.open_walkthrough() end, "Open Jetski walkthrough")
  bind("n", km.artifacts, function() artifacts.list_artifacts() end, "Browse Jetski artifacts")

  -- Register group names with which-key if available
  local ok_wk, wk = pcall(require, "which-key")
  if ok_wk and wk then
    local prefix = config.get().keymap_prefix or "<leader>J"
    pcall(function()
      if type(wk.add) == "function" then
        -- which-key.nvim v3+
        wk.add({
          { prefix, group = "Jetski", icon = "🚀" },
          { "<leader>y", group = "Jetski Diff Review", icon = "⚖️" },
        })
      elseif type(wk.register) == "function" then
        -- which-key.nvim v2
        local reg = {}
        reg[prefix] = { name = "+Jetski" }
        reg["<leader>y"] = { name = "+Jetski Diff" }
        wk.register(reg)
      end
    end)
  end
end

--- Toggles the Jetski sidebar/terminal window.
function M.toggle()
  terminal.toggle()
end

--- Opens the Jetski panel.
---@param opts? table Options passed to terminal.open
function M.open(opts)
  terminal.open(opts)
end

--- Closes the Jetski panel window.
function M.close()
  terminal.close_window()
end

--- Starts the Jetski process in a hidden background buffer without opening a window.
---@param opts? table Options passed to terminal.preload
function M.preload(opts)
  terminal.preload(opts)
end

--- Kills the active Jetski session process.
---@param silent? boolean If true, suppress user notification
function M.kill(silent)
  terminal.kill(silent)
end

--- Starts a new Jetski session.
---@param prompt? string Optional initial prompt
function M.new_session(prompt)
  terminal.open({ prompt = prompt, new_session = true })
end

--- Continues the last Jetski session.
---@param prompt? string Optional prompt to follow up with
function M.continue_session(prompt)
  terminal.open({ prompt = prompt, continue_session = true })
end

--- Asks Jetski a question with attached buffer or selection context.
---@param user_query? string Optional query (prompts via vim.ui.input if omitted)
function M.ask(user_query)
  if user_query and user_query ~= "" then
    local full_prompt = context.build_ask_prompt(user_query)
    terminal.open({ prompt = full_prompt })
  else
    vim.ui.input({ prompt = "Ask Jetski: " }, function(input)
      if input and vim.trim(input) ~= "" then
        local full_prompt = context.build_ask_prompt(vim.trim(input))
        terminal.open({ prompt = full_prompt })
      end
    end)
  end
end

--- Prompts Jetski to explain the selected code or current function.
function M.explain()
  local prompt = context.build_explain_prompt()
  terminal.open({ prompt = prompt })
end

--- Prompts Jetski to refactor the selected code.
---@param instruction? string Optional specific refactoring guidance
function M.refactor(instruction)
  if instruction then
    local prompt = context.build_refactor_prompt(instruction)
    terminal.open({ prompt = prompt })
  else
    vim.ui.input({ prompt = "Refactoring guidance (optional): " }, function(input)
      local prompt = context.build_refactor_prompt(input)
      terminal.open({ prompt = prompt })
    end)
  end
end

--- Prompts Jetski to fix compiler / LSP / Tricorder diagnostics in the current buffer.
---@param line_only? boolean If true, fix only cursor line diagnostics
function M.fix(line_only)
  local prompt = context.build_fix_prompt(line_only)
  if not prompt then
    vim.notify("[Jetski] No diagnostics or errors found in current buffer to fix!", vim.log.levels.INFO)
    return
  end
  terminal.open({ prompt = prompt })
end

--- Prompts Jetski to generate unit tests for the selected code.
function M.test()
  local prompt = context.build_test_prompt()
  terminal.open({ prompt = prompt })
end

--- Starts diff review for the specified file or current buffer.
---@param filepath? string
function M.diff_review(filepath)
  diff.review_diff(filepath)
end

--- Accepts agent edits.
---@param filepath? string
function M.diff_accept(filepath)
  diff.accept_diff(filepath)
end

--- Rejects agent edits.
---@param filepath? string
function M.diff_reject(filepath)
  diff.reject_diff(filepath)
end

--- Closes active diff review.
function M.diff_close()
  diff.close_diff_review()
end
M.close_diff = M.diff_close

--- Opens implementation plan artifact.
---@param path? string
function M.open_plan(path)
  artifacts.open_plan(path)
end

--- Opens walkthrough artifact.
---@param path? string
function M.open_walkthrough(path)
  artifacts.open_walkthrough(path)
end

--- Browse artifacts picker.
function M.list_artifacts()
  artifacts.list_artifacts()
end

--- Opens a file at line and column (RPC method called by agent).
---@param filepath string
---@param line? number
---@param col? number
function M.open_file(filepath, line, col)
  terminal.open_file(filepath, line, col)
end

--- Opens multiple files across splits (RPC method called by agent).
---@param files table
function M.open_files(files)
  terminal.open_files(files)
end

--- Copies the companion skill to ~/.gemini/jetski/skills/nvim/SKILL.md.
function M.update_skill()
  skill.update_skill()
end

--- Displays current status in a popup notification.
function M.status()
  local ws = workspace.detect_workspace()
  local is_act = terminal.is_active()
  local is_vis = terminal.is_open()
  local comments_count = #comments.get_all_comments()

  local status_lines = {
    "--- Jetski Neovim Plugin Status ---",
    string.format("Process Active: %s", is_act and "YES" or "NO"),
    string.format("Panel Visible:  %s", is_vis and "YES" or "NO"),
    string.format("Preload Mode:   %s", config.get().preload and "ENABLED" or "DISABLED"),
    string.format("Layout Mode:    %s", config.get().open_mode),
    string.format("CLI Binary:     %s", config.get().cmd),
    string.format("Workspace Type: %s", ws.type),
    string.format("Workspace Root: %s", ws.workspace_root or "[none]"),
    string.format("Pending Comments: %d", comments_count),
    string.format("RPC Server ($NVIM): %s", vim.v.servername or "[unset]"),
  }
  vim.notify(table.concat(status_lines, "\n"), vim.log.levels.INFO)
end

return M
