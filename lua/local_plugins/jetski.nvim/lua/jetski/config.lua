--- Configuration manager for jetski.nvim
local M = {}

--- Auto-detect available Jetski CLI binary on system.
---@return string
function M.detect_binary()
  local candidates = {
    "/google/bin/releases/jetski-devs/tools/cli",
    "/google/bin/releases/gemini-agents-jetski/jetski",
    "jetski",
    "cli",
  }
  for _, bin in ipairs(candidates) do
    if bin:sub(1, 1) == "/" then
      if vim.fn.filereadable(bin) == 1 and vim.fn.executable(bin) == 1 then
        return bin
      end
    else
      if vim.fn.executable(bin) == 1 then
        return bin
      end
    end
  end
  return "/google/bin/releases/jetski-devs/tools/cli"
end

--- Default options for jetski.nvim
M.defaults = {
  -- Path to Jetski CLI binary. Automatically detected if nil or empty.
  cmd = "",

  -- Default agent (e.g. "default", "code-knowledge", or custom agent name)
  agent = nil,

  -- Default model (e.g. "gemini-2.5-pro", "gemini-2.5-flash")
  model = nil,

  -- Reasoning effort level ("low", "medium", "high")
  effort = nil,

  -- Window layout mode: "vertical", "horizontal", "float", "tab", "replace"
  open_mode = "vertical",

  -- Settings for vertical split layout
  vertical = {
    side = "right", -- "right" or "left"
    width = 0.45,   -- float (fraction of editor columns, e.g. 0.45) or integer (fixed columns)
  },

  -- Settings for horizontal split layout
  horizontal = {
    side = "below", -- "below" or "above"
    height = 0.38,  -- float (fraction of editor lines, e.g. 0.38) or integer (fixed lines)
  },

  -- Settings for floating window layout
  float = {
    width = 0.85,
    height = 0.85,
    border = "rounded",
    title = " Jetski Agent ",
  },

  -- Controls whether initial skill reminder prompt is passed to the agent
  skill_prompt = true,

  -- Controls whether to skip checking for ~/.gemini/jetski/skills/nvim/SKILL.md
  skip_skill_check = false,

  -- Automatically reload buffers modified by Jetski on disk
  auto_revert = true,

  -- Automatically load/warm up Jetski CLI in a hidden background buffer on startup
  preload = true,

  -- Automatically kill Jetski process and wipe buffer when Neovim exits
  kill_on_exit = true,

  -- Automatically close window and wipe buffer when the Jetski process terminates
  auto_close = true,

  -- Global keymap prefix (default: "<leader>J" so it does not conflict with Jujutsu "<leader>j")
  keymap_prefix = "<leader>J",

  -- Automatically register default keymaps
  enable_default_keymaps = true,

  -- Keybindings configuration
  keymaps = {
    toggle = "<leader>Jj",
    new_session = "<leader>Jn",
    continue_session = "<leader>Jk",
    ask = "<leader>Ja",
    explain = "<leader>Je",
    refactor = "<leader>Jr",
    fix = "<leader>Jf",
    test = "<leader>Jt",
    comment = "<leader>Jc",
    comment_delete = "<leader>Jd",
    comment_list = "<leader>Jl",
    comment_submit = "<leader>Js",
    comment_clear = "<leader>JC",
    diff_review = "<leader>yd",
    diff_accept = "<leader>ya",
    diff_reject = "<leader>yr",
    diff_close = "<leader>yq",
    open_plan = "<leader>Jp",
    open_walkthrough = "<leader>Jw",
    artifacts = "<leader>JA",
  },

  -- Commenting and code review annotations (par with Cider-J CommentsManager)
  comments = {
    sign = "💬",
    sign_hl = "DiagnosticInfo",
    virtual_text = true,
    virtual_text_hl = "Comment",
    float_border = "rounded",
    auto_clear_on_submit = true,
  },

  -- Diff review configuration (par with Cider-J AgentEditManager)
  diff = {
    layout = "vertical", -- "vertical" (vsplit) or "horizontal" (split)
    auto_accept_on_commit = true,
  },

  -- Terminal configuration
  terminal = {
    escape_key = true,     -- Maps <Esc><Esc> to exit terminal mode without conflicting with CLI's <Esc>
    auto_insert = true,    -- Enter insert mode automatically on terminal focus
    scrollback = 10000,
  },

  -- Prompt templates for quick actions
  prompt_templates = {
    explain = "Please explain the following code snippet from `%s` (lines %d-%d):\n\n```%s\n%s\n```",
    refactor = "Please refactor the following code snippet from `%s` (lines %d-%d) following Google best practices and modern language idioms:\n\n```%s\n%s\n```",
    fix = "Please analyze and fix the following diagnostics/errors in `%s`:\n\n%s\n\nSurrounding Code:\n```%s\n%s\n```",
    test = "Please write comprehensive unit tests for the following code snippet from `%s` (lines %d-%d). Include edge cases and follow Google3 testing conventions:\n\n```%s\n%s\n```",
  },
}

M.options = {}

--- Initializes and merges user options with defaults.
---@param opts? table User options
---@return table
function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
  if not M.options.cmd or M.options.cmd == "" then
    M.options.cmd = M.detect_binary()
  end
  return M.options
end

--- Retrieves current options.
---@return table
function M.get()
  if vim.tbl_isempty(M.options) then
    M.setup()
  end
  return M.options
end

return M
