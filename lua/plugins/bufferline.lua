return {
	"akinsho/bufferline.nvim",
	dependencies = {
		"nvim-tree/nvim-web-devicons",
	},
	opts = {
		options = {
			diagnostics = "nvim_lsp",
			diagnostics_indicator = function(_, _, diagnostics_dict, _)
				local indicator = " "
				for level, number in pairs(diagnostics_dict) do
					local symbol
					if level == "error" then
						symbol = " "
					elseif level == "warning" then
						symbol = " "
					else
						symbol = " "
					end
					indicator = indicator .. number .. symbol
				end
				return indicator
			end,
		},
	},
	keys = {
		{ "<A-,>", ":BufferLineCyclePrev<CR>", silent = true },
		{ "<A-.>", ":BufferLineCycleNext<CR>", silent = true },
		{ "<leader>bp", ":BufferLinePick<CR>", silent = true },
		-- { "<leader>bd", ":bdelete<CR>", silent = true },
		{ "<A-1>", ":BufferLineGoToBuffer 1<CR>", silent = true },
		{ "<A-2>", ":BufferLineGoToBuffer 2<CR>", silent = true },
		{ "<A-3>", ":BufferLineGoToBuffer 3<CR>", silent = true },
		{ "<A-4>", ":BufferLineGoToBuffer 4<CR>", silent = true },
		{ "<A-5>", ":BufferLineGoToBuffer 5<CR>", silent = true },
		{ "<A-6>", ":BufferLineGoToBuffer 6<CR>", silent = true },
		{ "<A-7>", ":BufferLineGoToBuffer 7<CR>", silent = true },
		{ "<A-8>", ":BufferLineGoToBuffer 8<CR>", silent = true },
		{ "<A-9>", ":BufferLineGoToBuffer 9<CR>", silent = true },
		{ "<A-<>", ":BufferLineMovePrev<CR>", silent = true },
		{ "<A->>", ":BufferLineMoveNext<CR>", silent = true },
	},
	lazy = false,
}
