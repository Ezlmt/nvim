# jetski.nvim ⚡

> **Seamless, Agentic Jetski AI Integration for Neovim — At Par with Cider-J**

`jetski.nvim` bridges Neovim and Google's Jetski AI coding assistant, delivering the complete agentic developer experience previously exclusive to Cider-J and the Jetski Desktop IDE directly to terminal Neovim users.

---

## 🌟 Cider-J Feature Parity Matrix

| Feature | Cider-J | Legacy Editor Scripts | `jetski.nvim` |
| :--- | :---: | :---: | :---: |
| **Interactive Agent Panel** (Sidebar / Float / Split) | ✅ | ❌ (replace window only) | ✅ **Full layout control** (vertical, horizontal, float, tab) |
| **Active Editor Context** (File, Cursor, Visible Range) | ✅ | ❌ | ✅ **Automatic context capture** |
| **Visual Selection Prompts** (Explain, Refactor, Test) | ✅ | ❌ | ✅ **One-key actions** (`<leader>Je`, `<leader>Jr`, `<leader>Jt`) |
| **LSP & Compiler Diagnostics Fixes** | ✅ | ❌ | ✅ **Auto-diagnostic extraction & repair** (`<leader>Jf`) |
| **Inline Code Review Comments** (`CommentsManager`) | ✅ | Partial (primitive float) | ✅ **Full parity**: Gutter signs (💬), virtual text, range capture, batch submission |
| **Interactive Agent Diff Review** (`AgentEditManager`) | ✅ | ❌ | ✅ **Side-by-side diff review**, Accept all (`<leader>ya`), Reject all (`<leader>yr`) |
| **Automatic Buffer Reloading** (External Edits) | ✅ | ❌ | ✅ **Safe `checktime` / `autoread` synchronization** |
| **Artifacts & Implementation Plans** | ✅ | ❌ | ✅ **Direct artifact buffer viewer** (`:JetskiPlan`, `:JetskiWalkthrough`) |
| **Google3 / CitC Workspace Awareness** | ✅ | ❌ | ✅ **Auto-detects CitC client, user, depot paths (`//depot/...`)** |
| **Bi-directional Remote Neovim RPC** | ✅ | Partial | ✅ **Full RPC dispatch** (open files, review diffs, show plans) |
| **Non-colliding Keymaps** | N/A | Collided with Jujutsu `<leader>j` | ✅ **Configurable prefix** (defaults to `<leader>J`) |
| **Health Check Diagnosis** | N/A | ❌ | ✅ **`:checkhealth jetski`** |

---

## 🏗️ Architecture

```text
┌────────────────────────────────────────────────────────┐
│                      Neovim Host                       │
│                                                        │
│   ┌─────────────────────┐    ┌─────────────────────┐   │
│   │   Code Buffer(s)    │    │  Jetski Panel (UI)  │   │
│   │  - Gutter signs (💬)│    │  - Vertical Split   │   │
│   │  - Virtual text     │◄──►│  - Horizontal Split │   │
│   │  - Diff Review      │    │  - Centered Float   │   │
│   └──────────▲──────────┘    └──────────▲──────────┘   │
│              │                          │              │
│              │      Neovim RPC ($NVIM)  │              │
│              └──────────────────────────┘              │
└───────────────────────────┬────────────────────────────┘
                            │ (Process / Job Channel)
                            ▼
              ┌───────────────────────────┐
              │     Jetski CLI Engine     │
              │  (/google/bin/.../cli)    │
              └─────────────┬─────────────┘
                            │ (Stubby RPC / Loas)
                            ▼
              ┌───────────────────────────┐
              │  Jetski Language Server   │
              │     & Gemini Backend      │
              └───────────────────────────┘
```

---

## 📦 Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim) (Recommended)

Add to your `plugins.lua`:

```lua
{
  "jetski",
  dir = "/google/src/cloud/nachiketb/jetski_neovim_plugin_integration/google3/experimental/users/nachiketb/jetski.nvim",
  -- Or when committed to sso: url = "sso://user/nachiketb/jetski.nvim",
  opts = {
    open_mode = "vertical", -- "vertical" | "horizontal" | "float" | "tab"
    vertical = {
      side = "right",
      width = 0.45,
    },
    keymap_prefix = "<leader>J", -- Default prefix avoids Jujutsu <leader>j conflicts
    auto_revert = true,
    preload = true, -- Automatically warm up Jetski CLI in background buffer on nvim startup
  },
}
```

---

## ⚙️ Configuration

Call `require("jetski").setup(opts)` with any desired overrides. All options are optional:

```lua
require("jetski").setup({
  -- Path to CLI binary (automatically detected if nil/empty)
  cmd = "",

  -- Model and agent overrides
  model = nil,          -- e.g. "gemini-2.5-pro", "gemini-2.5-flash"
  agent = nil,          -- e.g. "code-knowledge" or custom agent name
  effort = nil,         -- "low" | "medium" | "high"

  -- Window layout: "vertical", "horizontal", "float", "tab", "replace"
  open_mode = "vertical",

  vertical = {
    side = "right",     -- "right" or "left"
    width = 0.45,       -- 45% screen width (or integer for fixed columns)
  },

  horizontal = {
    side = "below",     -- "below" or "above"
    height = 0.38,      -- 38% screen height
  },

  float = {
    width = 0.85,
    height = 0.85,
    border = "rounded",
    title = " Jetski Agent ",
  },

  -- Commenting and code review annotations (Cider-J CommentsManager parity)
  comments = {
    sign = "💬",
    sign_hl = "DiagnosticInfo",
    virtual_text = true,
    virtual_text_hl = "Comment",
    float_border = "rounded",
    auto_clear_on_submit = true,
  },

  -- Interactive diff review (Cider-J AgentEditManager parity)
  diff = {
    layout = "vertical",
    auto_accept_on_commit = true,
  },

  -- Terminal mode navigation
  terminal = {
    escape_key = true,   -- Maps <Esc><Esc> to exit terminal mode to normal mode
    auto_insert = true,  -- Automatically enter insert mode when focusing terminal
  },

  -- Background warmup & process lifecycle
  preload = true,       -- Automatically load/warm up Jetski CLI in a hidden background buffer
  kill_on_exit = true,  -- Automatically kill Jetski process and wipe buffer when Neovim exits
  auto_close = true,    -- Automatically close window and wipe buffer when Jetski process terminates

  -- Keybindings
  keymap_prefix = "<leader>J",
  enable_default_keymaps = true,
})
```

---

## ⌨️ Default Keymaps

| Keybinding | Mode | Description |
| :--- | :---: | :--- |
| `<leader>Jj` | Normal | **Toggle Jetski Panel** (Open / Hide) |
| `<leader>Jn` | Normal | **New Session** (Start a fresh conversation) |
| `<leader>Jk` | Normal | **Continue Session** (Resume last conversation) |
| `<leader>Ja` | Normal / Visual | **Ask Jetski** (Attaches active buffer or visual selection context) |
| `<leader>Je` | Normal / Visual | **Explain Code** (Prompts agent to explain selected code) |
| `<leader>Jr` | Normal / Visual | **Refactor Code** (Prompts agent to refactor with Google best practices) |
| `<leader>Jf` | Normal | **Fix Diagnostics** (Extracts LSP / compiler / Tricorder errors and prompts fix) |
| `<leader>Jt` | Normal / Visual | **Generate Unit Tests** for selected code |
| `<leader>Jc` | Normal / Visual | **Add / Edit Comment** on current line or selection range |
| `<leader>Jd` | Normal | **Delete Comment** on current line |
| `<leader>Jl` | Normal | **List Pending Comments** in Quickfix list |
| `<leader>Js` | Normal | **Submit Comments** in batch to Jetski as a structured review prompt |
| `<leader>JC` | Normal | **Clear All Comments** and indicators |
| `<leader>yd` | Normal | **Review Agent Diff** (Side-by-side comparison with pre-edit snapshot) |
| `<leader>ya` | Normal | **Accept All Agent Edits** |
| `<leader>yr` | Normal | **Reject / Revert Agent Edits** to pre-edit state |
| `<leader>Jp` | Normal | **Open Implementation Plan** |
| `<leader>Jw` | Normal | **Open Walkthrough** |
| `<leader>JA` | Normal | **Browse Session Artifacts** |
| `<Esc><Esc>` | Terminal | **Exit Terminal Mode** to normal window navigation (`<C-\><C-n>`) |

---

## 🚀 Workflows & Features

### 1. In-Editor Code Review Comments (Cider-J Parity)
1. Navigate to code you want the agent to review or modify.
2. Press `<leader>Jc` on a line (or select lines in visual mode and press `<leader>Jc`).
3. Type your instructions in the floating window (e.g. *"Refactor this method to use `context.Context`"*).
4. Save with `<CR>` or `<C-s>`. Gutter sign `💬` and virtual text appear.
5. Repeat across multiple files or lines.
6. Review your pending comments at any time with `<leader>Jl`.
7. Press `<leader>Js` to batch-submit all comments directly to Jetski! Indicators clear automatically.

### 2. Interactive Agent Diff Review & Accept / Reject
When the agent updates files in your workspace:
1. Run `:JetskiDiff` or press `<leader>yd` to review changes.
2. An interactive side-by-side diff opens with the original snapshot on the left and the agent-modified version on the right.
3. Jump between changes with `]c` and `[c`.
4. Press `<leader>ya` (`:JetskiAccept`) to keep all changes.
5. Press `<leader>yr` (`:JetskiReject`) to revert the file to its pre-edit state.

### 3. Fixing Compiler and Linter Errors with One Key
1. If your buffer has LSP or compiler errors (from `clangd`, `pyright`, `gopls`, or Tricorder), press `<leader>Jf` (`:JetskiFix`).
2. `jetski.nvim` extracts all diagnostics, line numbers, error codes, and surrounding context.
3. Jetski immediately starts working on fixing the compile breakages.

### 4. Viewing Implementation Plans & Artifacts
1. Press `<leader>Jp` to open the latest `implementation_plan.md` in a split buffer.
2. Press `<leader>JA` to browse all generated session artifacts with a fuzzy picker.

---

## 🩺 Health Check

Run `:checkhealth jetski` in Neovim at any time to verify:
- Neovim version compatibility
- Jetski CLI binary installation
- CitC / Google3 workspace detection
- Active Neovim RPC socket (`$NVIM`)
- Companion skill installation
