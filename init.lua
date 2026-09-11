vim.g.loaded_matchparen = 1
require("core.init")
require("daps.init")

-- 动态启用已安装的 LSP 服务器，避免缺失可执行文件导致启动报错
local lsp_servers = { "clangd" }
local mason_bin = vim.fn.stdpath("data") .. "/mason/bin/"

if vim.fn.executable("lua-language-server") == 1 or vim.fn.executable(mason_bin .. "lua-language-server") == 1 then
	table.insert(lsp_servers, "lua_ls")
end
if vim.fn.executable("gopls") == 1 or vim.fn.executable(mason_bin .. "gopls") == 1 then
	table.insert(lsp_servers, "gopls")
end
if vim.fn.executable("rust-analyzer") == 1 or vim.fn.executable(mason_bin .. "rust-analyzer") == 1 then
	table.insert(lsp_servers, "rust_analyzer")
end
if vim.fn.executable("typescript-language-server") == 1 or vim.fn.executable(mason_bin .. "typescript-language-server") == 1 then
	table.insert(lsp_servers, "ts_ls")
end

vim.lsp.enable(lsp_servers)

vim.api.nvim_set_hl(0, "LineNrAbove", { fg = "#7f849c" })
vim.api.nvim_set_hl(0, "LineNrBelow", { fg = "#7f849c" })

vim.opt.scrolloff = 4
