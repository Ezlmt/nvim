require "core.init"
require "daps.init"

vim.lsp.enable "lua_ls"
vim.lsp.enable "clangd"

vim.api.nvim_set_hl(0, "LineNrAbove",   { fg = "#7f849c" })
vim.api.nvim_set_hl(0, "LineNrBelow",   { fg = "#7f849c" })
