return {
	{
		"nvim-treesitter/nvim-treesitter",
		optional = true,
		ops = {
			ensure_installed = { "go", "gomod", "gosum", "gowork" },
		},
		opts_extend = { "ensure_installed" },
	},
	{
		"mason-org/mason.nvim",
		optional = true,
		opts = {
			ensure_installed = {
				"gopls",
			},
		},
		opts_extend = { "ensure_installed" },
	},
	{
		"stevearc/conform.nvim",
		optional = true,
		opts = {
			formatters_by_ft = {
				go = { "goimports" },
				gomod = { "goimports" },
			},
		},
	},
}
