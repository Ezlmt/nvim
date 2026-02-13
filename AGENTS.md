# PROJECT KNOWLEDGE BASE

**Generated:** 2026-02-13
**Commit:** a9280ae
**Branch:** main

## OVERVIEW

Personal Neovim configuration using lazy.nvim plugin manager with modular Lua structure. Catppuccin theme, blink.cmp completion, snacks.nvim utilities, Lspsaga LSP UI, inlay hints auto-enable, custom matchparen, rainbow-delimiters.

## STRUCTURE

```
nvim/
├── init.lua           # Entry: loads core, daps, enables LSP servers (also disables built-in matchparen)
├── lua/
│   ├── core/          # Settings, keymaps, lazy bootstrap, LSP attach, custom matchparen
│   ├── plugins/       # lazy.nvim plugin specs
│   └── daps/          # DAP configurations (cpp)
├── lsp/               # NON-STANDARD: Native LSP server configs (vim.lsp.enable)
└── snippets/          # Custom snippets
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Add plugin | `lua/plugins/<name>.lua` | Return lazy.nvim spec table |
| Change keymap | `lua/core/keymap.lua` | Or inline in plugin spec `keys={}` |
| Diagnostics UI | `lua/plugins/lspsage.lua` | Lspsaga mappings |
| Terminal UX | `lua/plugins/snacks.lua` | Toggle terminal, pickers, toggles |
| Add LSP server | `lsp/<server>.lua` + `init.lua` | Add to `vim.lsp.enable()` list |
| LSP attach behavior | `lua/core/lsp.lua` | Formatting disabled; inlay hints auto-enable |
| Inlay hints (per server) | `lsp/*.lua` | Server-specific settings |
| Match paren highlight | `lua/core/matchparen.lua` + `init.lua` | Only highlights the matching bracket |
| Rainbow delimiter colors | `lua/plugins/catppuccin.lua` | `custom_highlights` + integration |
| Modify options | `lua/core/basic.lua` | `vim.opt.*` settings |
| Add DAP config | `lua/daps/<lang>.lua` | Require in `lua/daps/init.lua` |
| Change theme | `lua/plugins/catppuccin.lua` | |

## CONVENTIONS

- **Indentation**: 2 spaces (`tabstop=2`, `shiftwidth=0`)
- **Formatting**: `conform.nvim` + `stylua` for Lua; LSP formatting **disabled**
- **Leader**: `<Space>` / LocalLeader: `,`
- **Plugin loading**: Prefer `event="VeryLazy"`, `cmd`, or `keys` triggers
- **LSP configs**: Top-level `/lsp/` dir (non-standard, uses `vim.lsp.enable`)
- **Inlay hints**: Auto-enabled per-buffer on `LspAttach` when server supports `textDocument/inlayHint`
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
| `<c-/>` | n | Toggle terminal (snacks) |
| `<leader>th` | n | Toggle inlay hints (snacks) |
| `gd` / `gr` / `gI` | n | LSP definition/references/implementation |
| `<leader>ll` | n | Show line diagnostics (Lspsaga) |
| `<leader>l*` | n | Lspsaga commands |

## PLUGIN HIGHLIGHTS

| Plugin | Purpose | Config |
|--------|---------|--------|
| `snacks.nvim` | Dashboard, picker, explorer, zen, terminal, toggles | `lua/plugins/snacks.lua` |
| `blink.cmp` | Completion engine | `lua/plugins/blink.lua` |
| `conform.nvim` | Format on save | `lua/plugins/conform.lua` |
| `lspsaga.nvim` | LSP UI enhancements | `lua/plugins/lspsage.lua` |
| `rainbow-delimiters.nvim` | Rainbow bracket highlight (treesitter) | `lua/plugins/rainbow-delimiters.lua` |
| `catppuccin` | Colorscheme + highlight integration | `lua/plugins/catppuccin.lua` |
| `bufferline.nvim` | Tab bar | `lua/plugins/ui.lua` |
| `gitsigns.nvim` | Git decorations | `lua/plugins/ui.lua` |

## LSP SERVERS

Enabled in `init.lua` via `vim.lsp.enable()`:
- `lua_ls` - Lua (Mason-installed)
- `clangd` - C/C++ (C++23 default)
- `gopls` - Go (custom root_dir logic)
- `tsserver` - TypeScript
- `rust_analyzer` - Rust (inlay hints supported when rust-analyzer installed)

## NOTES

- `/lsp/` is **outside** standard `lua/` tree - uses Neovim's native `vim.lsp.config` API
- Built-in matchparen is disabled (`vim.g.loaded_matchparen = 1`); custom logic lives in `lua/core/matchparen.lua`
- `snacks.nvim` overrides `vim.print` and adds `_G.dd`, `_G.bt` debug helpers
- GUI font: "Maple Mono NF CN" (Neovide config in `lua/core/neovide.lua`)
