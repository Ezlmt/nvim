return {
	"mason-org/mason.nvim",
	cmd = "Mason",
	event = "VeryLazy",
	build = ":MasonUpdate",
	opts = {
		ui = {
			border = "rounded",
		},
	},
}
