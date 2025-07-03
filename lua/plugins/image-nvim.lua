return {
	{
		"vhyrro/luarocks.nvim",
		priority = 1001, -- this plugin needs to run before anything else
		opts = {
			rocks = { "magick" },
		},
	},
	{
		"3rd/image.nvim",
		dependencies = { "luarocks.nvim" },
    cond = function()
      if vim.g.neovide or vim.g.goneovim or vim.g.GuiLoaded then
        return false
      end
      local ui_ok  = #vim.api.nvim_list_uis() > 0
      local term   = os.getenv("TERM") or ""
      return ui_ok and (term:match("kitty") or term:match("wezterm"))
    end,
		opts = {},
	},
}
