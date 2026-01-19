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

## Priority

1. **High**: Basic settings (#1) - improves stability
2. **Medium**: Keymaps (#2), LSP keymaps (#5) - improves workflow
3. **Low**: Treesitter (#3), Conform (#4), Cleanup (#6) - nice to have
