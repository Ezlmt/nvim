return {
  'folke/which-key.nvim',
  event = 'VeryLazy',
  dependencies = { "nvim-tree/nvim-web-devicons" },
  opts = {
    ---@type false | "calssic" | "modern" | "helix"
    preset = "helix",
    -- style: ignone
    spec = {
      { "<leader>s", group = "<Snacks>"},
      { "<leader>t", group = "<Snacks> Toggle"},
      { "<leader>g", group = "git"},
      { "<leader>l", group = "Lspsage"},
      { "<leader>f", group = "Find"},
      { "<leader>d", group = "Debug"},
    },
    -- expand all nodes witgout a  description
    expand = function (node)
      return not node.desc
    end
  },
  keys = {
    { "<leader>?", function () require("which-key").show({ global = false }) end, desc = "[Which-Key] Buffer Local Keymaps" },
  },
}
