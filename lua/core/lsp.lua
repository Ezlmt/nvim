vim.api.nvim_create_autocmd("LspAttach", {
	callback = function(ev)
		local client = vim.lsp.get_client_by_id(ev.data.client_id)
		if not client then
			return
		end

		-- 🔒 统一禁用 LSP 的格式化（如果你用外部 formatter）
		client.server_capabilities.documentFormattingProvider = false
		client.server_capabilities.documentRangeFormattingProvider = false

		-- 🧠 如果你用 blink.cmp，这里统一扩展 capabilities
		local ok, blink = pcall(require, "blink.cmp")
		if ok and blink.get_lsp_capabilities then
			client.capabilities = vim.tbl_deep_extend("force", client.capabilities or {}, blink.get_lsp_capabilities())
		end
	end,
})

vim.api.nvim_create_user_command("LspClients", function()
	print(vim.inspect(vim.lsp.get_clients({ bufnr = 0 })))
end, {})
