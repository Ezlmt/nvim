return {
  "akinsho/bufferline.nvim",
  dependencies = {
    "nvim-tree/nvim-web-devicons"
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
      end
    },
  },
  keys = {
    { "<leader>bh", ":BufferLineCyclePrev<CR>", silent = true },
    { "<leader>bl", ":BufferLineCycleNext<CR>", silent = true },
    { "<leader>bp", ":BufferLinePick<CR>",      silent = true },
    { "<leader>bd", ":bdelete<CR>",             silent = true },
  },
  lazy = false,
}
