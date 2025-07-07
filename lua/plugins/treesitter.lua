return {
	"nvim-treesitter/nvim-treesitter",
	event = "VeryLazy",
	main = "nvim-treesitter.configs",
	opts = {
		ensure_installed = { "lua", "toml", "cpp", "c", "python",
      "css",
      "latex",
    },
		highlight = { enable = true },
    indent = { enable = true },
	},
  opts_extend = { "ensure_installed" },
}
