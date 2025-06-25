return {
	"mason-org/mason.nvim",
	event = "VeryLazy",
	-- event = { "BufReadPost", "BufNewFile", "VimEnter" },
	dependencies = {
		"neovim/nvim-lspconfig",
		"mason-org/mason-lspconfig.nvim",
	},
	opts = {},
	config = function(_, opts)
		require("mason").setup(opts)
		local registry = require("mason-registry")

		local function setup(name, config)
			local success, package = pcall(registry.get_package, name)
			if success and not package:is_installed() then
				package:install()
			end
			local nvim_lsp = require("mason-lspconfig").get_mappings().package_to_lspconfig[name]
			config.capabilities = require("blink.cmp").get_lsp_capabilities()
			config.on_attach = function(client)
				client.server_capabilities.documentFormattingProvider = false
				client.server_capabilities.documentRangeFormattingProvider = false
			end
			require("lspconfig")[nvim_lsp].setup(config)
		end

		local servers = {
		  ["lua-language-server"] = {
				settings = {
					Lua = {
						diagnostics = {
							globals = { "vim" },
						},
					},
				},
			},
			pyright = {},
		}

		for server, config in pairs(servers) do
			setup(server, config)
		end

		vim.cmd("LspStart")
		vim.diagnostic.config({
			virtual_text = true,
			-- virtual_lines = true,
			update_in_insert = true,
		})
	end,
}
