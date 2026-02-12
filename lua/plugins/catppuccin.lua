return {
  "catppuccin/nvim",
  name = "catppuccin",
  priority = 1000,
  config = function ()
    vim.opt.termguicolors = true
    require("catppuccin").setup({
      flavour = "mocha",
      transparent_background = true,
      term_colors = true,
      custom_highlights = function (colors)
        return {
          MatchParen = { bg = colors.lavender, fg = colors.base, bold = true },
        }
      end,
      integrations = {
        alpha = true,
        cmp = true,
        gitsigns = true,
        lsp_trouble = true,
        nvimtree = true,
        telescope = true,
        notify = true,
        rainbow_delimiters = true,
      },
    })
    vim.cmd("colorscheme catppuccin")
  end
}
