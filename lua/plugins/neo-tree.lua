return {
  "nvim-neo-tree/neo-tree.nvim",
  branch = "v3.x",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-tree/nvim-web-devicons", -- not strictly required, but recommended
    "MunifTanjim/nui.nvim",
    -- {"3rd/image.nvim", opts = {}}, -- Optional image support in preview window: See `# Preview Mode` for more information
  },
  lazy = false, -- neo-tree will lazily load itself
  ---@module "neo-tree"
  ---@type neotree.Config?
  opts = {
    -- fill any relevant options here
    window = {
      mappings = {
        ["l"] = "open",
        ["h"] = "close_node",
      },
    },
  },
  keys = {
    -- <leader>e —— 只负责 “聚焦 / 打开” Neo-tree
    {
      "<leader>e",
      function()
        vim.cmd("stopinsert")          -- 若在 i / t 模式先退出
        vim.cmd("Neotree toggle")       -- 打开并聚焦（已开则直接聚焦）
      end,
      desc  = "Neo-tree: Toggle + Focus",
      mode  = { "n", "i", "v", "t" },
      noremap = true, silent = true,
    },

    -- <leader>o —— 在编辑区和文件树之间来回跳
    {
      "<leader>o",
      function()
        vim.cmd("stopinsert")
        -- 如果当前窗口就是 Neo-tree，则回到上一个窗口；否则聚焦 Neo-tree
        if vim.bo.filetype == "neo-tree" then
          vim.cmd("wincmd p")          -- 回到之前的编辑窗口
        else
          vim.cmd("Neotree focus")     -- 或打开后聚焦
        end
      end,
      desc  = "Neo-tree: Toggle tree ↔ edit",
      mode  = { "n", "i", "v", "t" },
      noremap = true, silent = true,
    },
  },
}
