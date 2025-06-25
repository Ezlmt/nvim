return {
	"goolord/alpha-nvim",
	dependencies = { "nvim-tree/nvim-web-devicons" },

	config = function()
		local alpha = require("alpha")
		local dashboard = require("alpha.themes.dashboard")

		------------------------------------------------------------------
		-- 1. 头部 ASCII Art
		------------------------------------------------------------------
		dashboard.section.header.val = {
			"                                                    ",
			" ███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗ ",
			" ████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║ ",
			" ██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║ ",
			" ██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║ ",
			" ██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║ ",
			" ╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝ ",
			"",
			"     ███████╗███████╗██╗     ███╗   ███╗████████╗",
			"     ██╔════╝╚══███╔╝██║     ████╗ ████║╚══██╔══╝",
			"     █████╗    ███╔╝ ██║     ██╔████╔██║   ██║",
			"     ██╔══╝   ███╔╝  ██║     ██║╚██╔╝██║   ██║",
			"     ███████╗███████╗███████╗██║ ╚═╝ ██║   ██║",
			"     ╚══════╝╚══════╝╚══════╝╚═╝     ╚═╝   ╚═╝",
		}

		------------------------------------------------------------------
		-- 2. 中间按钮 (可选，自行调整)
		------------------------------------------------------------------
		-- dashboard.section.buttons.val = {
		-- 	dashboard.button("e", "  New file", ":ene <BAR> startinsert<CR>"),
		-- 	dashboard.button("r", "  Recent   ", ":Telescope oldfiles<CR>"),
		-- 	dashboard.button("p", "  Projects ", ":Telescope projects<CR>"),
		-- 	dashboard.button("q", "  Quit NVIM", ":qa<CR>"),
		-- }

		------------------------------------------------------------------
		-- 3. Footer (可选)
		------------------------------------------------------------------
		dashboard.section.footer.val = { "Happy hacking  " }

		dashboard.section.header.opts = { hl = "AlphaHeader", position = "center" }
		dashboard.section.buttons.opts = { hl = "AlphaButtons", position = "center" }
		dashboard.section.footer.opts = { hl = "AlphaFooter", position = "center" }

		local cp = require("catppuccin.palettes").get_palette()
		vim.api.nvim_set_hl(0, "AlphaHeader", { fg = cp.blue, bold = true })
		vim.api.nvim_set_hl(0, "AlphaButtons", { fg = cp.teal, bold = true })
		vim.api.nvim_set_hl(0, "AlphaFooter", { fg = cp.yellow, bold = true, italic = true })

		------------------------------------------------------------------
		-- 4. 最后让 Alpha 加载你的 dashboard
		------------------------------------------------------------------
		alpha.setup(dashboard.config)
	end,
}
