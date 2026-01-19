# Neovim Config Optimization TODO

## 1. Basic Settings (basic.lua)

Add these essential options:

```lua
vim.opt.undofile = true              -- 持久化 undo 历史
vim.opt.updatetime = 250             -- 更快的 CursorHold（默认 4000ms）
vim.opt.timeoutlen = 300             -- which-key 响应更快
vim.opt.signcolumn = "yes"           -- 避免 LSP 诊断时界面跳动
vim.opt.termguicolors = true         -- 真彩色支持
vim.opt.wrap = false                 -- 长行不换行（可选）
vim.opt.mouse = "a"                  -- 鼠标支持（可选）
```

## 2. Keymaps Enhancement (keymap.lua)

```lua
-- 保存快捷键
map("n", "<C-s>", "<cmd>w<CR>", { desc = "Save file" })
map({ "i", "x" }, "<C-s>", "<Esc><cmd>w<CR>", { desc = "Save file" })

-- 更好的缩进（保持选中）
map("v", "<", "<gv")
map("v", ">", ">gv")

-- 移动行
map("n", "<A-j>", "<cmd>m .+1<CR>==", { desc = "Move line down" })
map("n", "<A-k>", "<cmd>m .-2<CR>==", { desc = "Move line up" })
map("v", "<A-j>", ":m '>+1<CR>gv=gv", { desc = "Move selection down" })
map("v", "<A-k>", ":m '<-2<CR>gv=gv", { desc = "Move selection up" })

-- 取消高亮
map("n", "<Esc>", "<cmd>noh<CR>", { desc = "Clear search highlight" })
```

## 3. Treesitter Enhancement (treesitter.lua)

Add incremental selection:

```lua
opts = {
  -- ... existing config ...
  incremental_selection = {
    enable = true,
    keymaps = {
      init_selection = "<C-space>",
      node_incremental = "<C-space>",
      scope_incremental = false,
      node_decremental = "<bs>",
    },
  },
},
```

## 4. Conform Extension (conform.lua)

Add more formatters:

```lua
formatters_by_ft = {
  lua = { "stylua" },
  rust = { "rustfmt" },
  go = { "gofmt", "goimports" },
  python = { "black" },
  javascript = { "prettier" },
  typescript = { "prettier" },
  json = { "prettier" },
  markdown = { "prettier" },
  ["_"] = { "trim_whitespace" },  -- 所有文件去除尾部空白
},
```

## 5. LSP Keymaps (lsp.lua)

Add common LSP keybindings in LspAttach:

```lua
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(ev)
    local opts = { buffer = ev.buf }
    vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
    vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts)
    vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
    vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, opts)
    vim.keymap.set("n", "]d", vim.diagnostic.goto_next, opts)
    -- ... existing code ...
  end,
})
```

## 6. Redundant Plugins (Optional Cleanup)

Consider removing if not using unique features:

| Plugin | Reason |
|--------|--------|
| `telescope.nvim` | snacks.picker covers all functionality |
| `lspsaga.nvim` | overlaps with snacks LSP picker (keep if you prefer its UI) |
| `toggleterm.nvim` | snacks.terminal already provides this |

---

# Main Branch Specific

## 7. Bugs to Fix

| Issue | Location | Fix |
|-------|----------|-----|
| Typo `ops` → `opts` | `lua/plugins/go.lua:5` | Change `ops` to `opts` |
| Keymap conflict | `yazi-nvim.lua` | `<leader>e` conflicts with snacks.explorer |
| Nested plugin spec | `yazi-nvim.lua:31-37` | neo-tree config inside yazi opts is wrong |

## 8. DAP Improvements

### Add Rust debugging support (lua/daps/rust.lua)

```lua
local dap = require("dap")
-- Reuse codelldb from cpp config
dap.configurations.rust = {
  {
    name = "Launch",
    type = "codelldb",
    request = "launch",
    program = function()
      return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/target/debug/", "file")
    end,
    cwd = "${workspaceFolder}",
    stopOnEntry = false,
  },
}
```

Then add `require("daps.rust")` to `lua/daps/init.lua`.

### DAP keymaps enhancement

```lua
-- Add to dap.lua keys section:
{ "<leader>du", function() require("dapui").toggle() end, desc = "Debug • Toggle UI" },
{ "<leader>de", function() require("dapui").eval() end, desc = "Debug • Eval", mode = { "n", "v" } },
{ "<leader>dt", function() require("dap").terminate() end, desc = "Debug • Terminate" },
```

## 9. Yazi Config Fix

Current config has issues - fix to:

```lua
return {
  "mikavilpas/yazi.nvim",
  event = "VeryLazy",
  dependencies = { "folke/snacks.nvim" },
  keys = {
    { "<leader>-", "<cmd>Yazi<cr>", mode = { "n", "v" }, desc = "Yazi (current file)" },
    { "<leader>yc", "<cmd>Yazi cwd<cr>", desc = "Yazi (cwd)" },  -- Changed from <leader>e
    { "<leader>yl", "<cmd>Yazi toggle<cr>", desc = "Yazi resume" },
  },
  opts = {
    open_for_directories = false,
    keymaps = { show_help = "<f1>" },
  },
}
```

## 10. LSP Server Improvements

### tsserver → ts_ls (Deprecated)

`tsserver` is deprecated, rename to `ts_ls`:
- Rename `lsp/tsserver.lua` → `lsp/ts_ls.lua`
- Update `init.lua`: change `"tsserver"` to `"ts_ls"` in `vim.lsp.enable()`

### Add more LSP servers (optional)

| Server | Language | Config |
|--------|----------|--------|
| `pyright` | Python | Standard config |
| `jsonls` | JSON | With schemastore |
| `yamlls` | YAML | With schemastore |

## 11. Image.nvim Optimization

Current `cond` function is good but can add fallback message:

```lua
cond = function()
  if vim.g.neovide then
    return false  -- snacks.image handles this in Neovide
  end
  local term = os.getenv("TERM") or ""
  return term:match("kitty") or term:match("wezterm")
end,
```

## 12. Mason ensure_installed

Consolidate all mason tools in one place (`mason.lua`):

```lua
opts = {
  ensure_installed = {
    -- LSP
    "lua-language-server",
    "typescript-language-server",
    "gopls",
    "rust-analyzer",
    -- Formatters
    "stylua",
    "prettier",
    "goimports",
    -- DAP
    "codelldb",
  },
},
```

---

## Priority

### Basic branch (shared)
1. **High**: Basic settings (#1) - improves stability
2. **Medium**: Keymaps (#2), LSP keymaps (#5) - improves workflow
3. **Low**: Treesitter (#3), Conform (#4), Cleanup (#6) - nice to have

### Main branch specific
1. **High**: Fix bugs (#7) - typos, keymap conflicts
2. **High**: tsserver deprecation (#10) - rename to ts_ls
3. **Medium**: DAP improvements (#8) - add Rust debugging
4. **Medium**: Yazi config fix (#9)
5. **Low**: Mason consolidation (#12), Image.nvim (#11)
