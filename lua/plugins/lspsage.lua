return {
	"nvimdev/lspsaga.nvim",
	cmd = "Lspsaga",
	opts = {
		finder = {
			keys = {
				toggle_or_open = "<CR>",
			},
		},
	},
	keys = {
		{ "<leader>lr", ":Lspsaga rename<CR>", desc = "Rename mutable"},
		{ "<leader>lc", ":Lspsaga code_action<CR>", desc = "Code action(Quick fix)" },
		{ "<leader>ld", ":Lspsaga goto_definition<CR>", desc = "Go to defination" },
		{ "<leader>lh", ":Lspsaga hover_doc<CR>", desc = "Hover documetation" },
		{ "<leader>lR", ":Lspsaga finder<CR>", desc = "Finder" },
		{ "<leader>ln", ":Lspsaga diagnostic_jump_next<CR>", desc = "Diagnostic jump next" },
		{ "<leader>lp", ":Lspsaga diagnostic_jump_prev<CR>", desc = "Diagnostic jump prev" },
	},
}
