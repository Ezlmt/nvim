return {
	{
		"windwp/nvim-autopairs",
		event = "InsertEnter",
		opts = {},
	},
	-- {
	-- 	"cappyzawa/trim.nvim",
	-- 	event = "BufWritePre",
	-- 	opts = {},
	-- },
	{
		"folke/todo-comments.nvim",
		dependencies = {
			"nvim-lua/plenary.nvim",
			"folke/snacks.nvim",
		},
		event = "VeryLazy",
		config = true,
		keys = {
			---@diagnostic disable-next-line: undefined-field
			{
				"<leader>st",
				function()
					require("snacks").picker.todo_comments({
						keywords = { "TODO", "FIX", "FIXME", "BUG", "FIXIT", "HACK", "WARN", "ISSUE" },
					})
				end,
				desc = "[TODO] Pick todos (without NOTE)",
			},
			---@diagnostic disable-next-line: undefined-field
			{
				"<leader>sT",
				function()
					require("snacks").picker.todo_comments()
				end,
				desc = "[TODO] Pick todos (with NOTE)",
			},
		},
	},
	{
		"kylechui/nvim-surround",
		event = "VeryLazy",
		opts = {},
	},
	{
		"smoka7/hop.nvim",
		opts = {
			hint_position = 3,
		},
		keys = {
			{ "<leader>fw", ":HopWord<CR>", silent = true, desc = "Find word" },
		},
	},
}
