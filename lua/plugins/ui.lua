return {
  {
    "lewis6991/gitsigns.nvim",
    event = "BufReadPost",
    opts = {
      signcolumn = false,
      numhl = true,
      attach_to_untracked = true,
      preview_config = {
        border = "rounded",
      },
    },
    config = function (_, opts)
      require("gitsigns").setup(opts)
      require("scrollbar.handlers.gitsigns").setup()
    end,
  },
  {
    "echasnovski/mini.diff",
    version = "*",
    keys = {
      { "<Leader>to", function() require("mini.diff").toggle_overlay(vim.api.nvim_get_current_buf()) end, mode = "n", desc = "[MiniDiff]"},
    },
    opts = {},
  },
  {
    "petertriho/nvim-scrollbar",
    opts = {
      handelers = {
        gitsigns = true,
        search = true,
      },
      marks = {
        Search = {
          color = "#CBA6F7"
        },
        GitAdd = { text = "|" },
        GitChange = { text = "|" },
        GitDeletef = { text = "_" },

      },
    },
  },
  {
    "kevinhwang91/nvim-hlslens",
    keys = {
      { "n", "nzz<Cmd>lua require('hlslens').start()<CR>", mode = "n", desc = "Next match", noremap = true, silent = true},
      { "N", "Nzz<Cmd>lua require('hlslens').start()<CR>", mode = "n", desc = "Previous match", noremap = true, silent = true},
      { "*", "*<Cmd>lua require('hlslens').start()<CR>", mode = "n", desc = "Next match", noremap = true, silent = true},
      { "#", "#<Cmd>lua require('hlslens').start()<CR>", mode = "n", desc = "Previous match", noremap = true, silent = true},
      { "g*", "g*<Cmd>lua require('hlslens').start()<CR>", mode = "n", desc = "Next match", noremap = true, silent = true},
      { "g#", "g#<Cmd>lua require('hlslens').start()<CR>", mode = "n", desc = "Previous match", noremap = true, silent = true},
      { "//", "<Cmd>noh<CR>",                               mode = "n", desc = "Clear highlight", noremap = true, silent = true },

      { "/" },
      { "?" },
    },
    opts = {
      nearest_only = true,
    },
    config = function (_, opts)
      require("scrollbar.handlers.search").setup(opts)
      vim.api.nvim_set_hl(0,"HlSearchLens",{ link = "CurSearch"} )
      vim.api.nvim_set_hl(0,"HlSearchLensNear",{ fg = "#CBA6F7"} )
    end,
  },
  {
    "norcalli/nvim-colorizer.lua",
    config = function (_, _)
      require("colorizer").setup()
    end,
  },
  {
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
  },
  {
    "nvim-lualine/lualine.nvim",
    dependencies = {
      "nvim-tree/nvim-web-devicons",
    },
    event = "VeryLazy",
    opts = {
      options = {
        theme = "auto",
        component_separators = { left = "", right = "" },
        section_separators = { left = "", right = "" },
      },
      extensions = { "nvim-tree" },
      sections = {
        lualine_b = { "branch", "diff" },
        lualine_x = {
          "filesize",
          "lsp_status",
        },
        lualine_y = {
          "encoding",
          "fileformat",
          "filetype",
          "progress",
        },
      },
    },
  },
}
