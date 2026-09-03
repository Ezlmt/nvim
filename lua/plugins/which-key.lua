return {
  'folke/which-key.nvim',
  event = 'VeryLazy',
  dependencies = { "nvim-tree/nvim-web-devicons" },
  opts = {
    ---@type false | "classic" | "modern" | "helix"
    preset = "helix",
    spec = {
      { "<leader>s", group = "Snacks / Search" },
      { "<leader>t", group = "Toggle" },
      { "<leader>g", group = "Git" },
      { "<leader>l", group = "Lspsaga / LSP" },
      { "<leader>f", group = "Find" },
      { "<leader>d", group = "Debug" },
    },
    -- expand all nodes without a description
    expand = function (node)
      return not node.desc
    end
  },
  keys = {
    { "<leader>?", function () require("which-key").show({ global = false }) end, desc = "[Which-Key] Buffer Local Keymaps" },
  },
}
