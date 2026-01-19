# PROJECT KNOWLEDGE BASE

**Generated:** 2026-01-18
**Commit:** a5d6fa1
**Branch:** main

## OVERVIEW

Personal Neovim configuration using lazy.nvim plugin manager with modular Lua structure. Catppuccin theme, blink.cmp completion, snacks.nvim utilities.

## STRUCTURE

```
nvim/
├── init.lua           # Entry: loads core, daps, enables LSP servers
├── lua/
│   ├── core/          # Settings, keymaps, lazy bootstrap, LSP attach
│   ├── plugins/       # lazy.nvim plugin specs (22 files)
│   └── daps/          # DAP configurations (cpp)
├── lsp/               # NON-STANDARD: Native LSP server configs (vim.lsp.enable)
└── snippets/          # Custom snippets
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Add plugin | `lua/plugins/<name>.lua` | Return lazy.nvim spec table |
| Change keymap | `lua/core/keymap.lua` | Or inline in plugin spec `keys={}` |
| Add LSP server | `lsp/<server>.lua` + `init.lua` | Add to `vim.lsp.enable()` list |
| Modify options | `lua/core/basic.lua` | `vim.opt.*` settings |
| Add DAP config | `lua/daps/<lang>.lua` | Require in `lua/daps/init.lua` |
| Change theme | `lua/plugins/catppuccin.lua` | |

## CONVENTIONS

- **Indentation**: 2 spaces (`tabstop=2`, `shiftwidth=0`)
- **Formatting**: `conform.nvim` + `stylua` for Lua; LSP formatting **disabled**
- **Leader**: `<Space>` / LocalLeader: `,`
- **Plugin loading**: Prefer `event="VeryLazy"`, `cmd`, or `keys` triggers
- **LSP configs**: Top-level `/lsp/` dir (non-standard, uses `vim.lsp.enable`)
- **Completion**: `blink.cmp` with super-tab preset

## ANTI-PATTERNS

- **NEVER** use LSP formatting (disabled in `lua/core/lsp.lua`)
- **NEVER** use `as any` type suppressions
- **AVOID** `@diagnostic disable` unless truly necessary

## KEY MAPPINGS

| Key | Mode | Action |
|-----|------|--------|
| `jk` | i | Escape |
| `<C-h/j/k/l>` | i | Cursor movement |
| `<C-h/j/k/l>` | n | Window navigation |
| `<S-H>` / `<S-L>` | n,x,o | Start/End of line |
| `<A-,>` / `<A-.>` | n | Buffer prev/next |
| `<leader>e` | n | File explorer (snacks) |
| `<leader><space>` | n | Smart find files |
| `<leader>/` | n | Grep |
| `<leader>gg` | n | Lazygit |
| `gd` / `gr` / `gI` | n | LSP definition/references/implementation |
| `<leader>l*` | n | Lspsaga commands |

## PLUGIN HIGHLIGHTS

| Plugin | Purpose | Config |
|--------|---------|--------|
| `snacks.nvim` | Dashboard, picker, explorer, zen, terminal | `lua/plugins/snacks.lua` |
| `blink.cmp` | Completion engine | `lua/plugins/blink.lua` |
| `conform.nvim` | Format on save | `lua/plugins/conform.lua` |
| `lspsaga.nvim` | LSP UI enhancements | `lua/plugins/lspsage.lua` |
| `bufferline.nvim` | Tab bar | `lua/plugins/ui.lua` |
| `gitsigns.nvim` | Git decorations | `lua/plugins/ui.lua` |

## LSP SERVERS

Enabled in `init.lua` via `vim.lsp.enable()`:
- `lua_ls` - Lua (Mason-installed)
- `clangd` - C/C++ (C++23 default)
- `gopls` - Go (custom root_dir logic)
- `tsserver` - TypeScript

## NOTES

- `/lsp/` is **outside** standard `lua/` tree - uses Neovim's native `vim.lsp.config` API
- `gopls.lua` has custom logic for `GOMODCACHE`/`GOROOT` handling
- `snacks.nvim` overrides `vim.print` and adds `_G.dd`, `_G.bt` debug helpers
- GUI font: "Maple Mono NF CN" (Neovide config in `lua/core/neovide.lua`)
