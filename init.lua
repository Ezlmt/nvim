vim.g.loaded_matchparen = 1
require("core.init")
require("daps.init")

vim.lsp.enable({
	"lua_ls",
	"clangd",
	"gopls",
	"tsserver",
	"rust_analyzer",
})

vim.api.nvim_set_hl(0, "LineNrAbove", { fg = "#7f849c" })
vim.api.nvim_set_hl(0, "LineNrBelow", { fg = "#7f849c" })

vim.opt.scrolloff = 4
