require("core.init")
require("daps.init")

vim.lsp.enable({
	"lua_ls",
	"clangd",
	"gopls",
	"tsserver",
})

vim.api.nvim_set_hl(0, "LineNrAbove", { fg = "#7f849c" })
vim.api.nvim_set_hl(0, "LineNrBelow", { fg = "#7f849c" })

vim.opt.scrolloff = 4
