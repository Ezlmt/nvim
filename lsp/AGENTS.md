# LSP SERVER CONFIGURATIONS

## OVERVIEW

Non-standard top-level directory for native Neovim LSP configs using `vim.lsp.config` API (not nvim-lspconfig plugin).

## HOW IT WORKS

1. Each `<server>.lua` returns a config table
2. `init.lua` calls `vim.lsp.enable({ "lua_ls", "clangd", ... })`
3. Neovim automatically loads matching files from `/lsp/` directory

## FILE FORMAT

```lua
return {
  cmd = { "server-binary" },
  filetypes = { "lang" },
  root_markers = { ".git", "project.json" },  -- OR root_dir function
  settings = { ... },
  capabilities = { ... },
}
```

## SERVERS

| File | Language | Notes |
|------|----------|-------|
| `lua_ls.lua` | Lua | Uses Mason path, recognizes `vim` global |
| `clangd.lua` | C/C++ | Default `-std=c++23`, custom capabilities |
| `gopls.lua` | Go | Custom `root_dir` for GOMODCACHE/GOROOT |
| `tsserver.lua` | TypeScript | Standard config |

## ADDING NEW SERVER

1. Create `lsp/<server_name>.lua` with config table
2. Add server name to `vim.lsp.enable()` in `/init.lua`
3. Ensure binary is in PATH or specify full path in `cmd`

## CONVENTIONS

- Use `root_markers` for simple cases, `root_dir` function for complex logic
- Mason binaries: `vim.fn.stdpath("data") .. "/mason/bin/<binary>"`
- Formatting disabled globally in `lua/core/lsp.lua` - don't enable here
