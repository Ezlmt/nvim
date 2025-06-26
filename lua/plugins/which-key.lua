-- return {
-- 	"folke/which-key.nvim",
-- 	event = "VeryLazy",
-- 	dependentcies = { "echasnovski/mini.icons" },
-- 	opts = {
-- 		win = {
-- 			border = "rounded",
-- 			padding = { 1, 2, 1, 2 },
-- 		},
-- 		triggers_blacklist = {
-- 			n = { "gc", "ys", "yS" }, -- normal 模式里忽略这几个前缀
-- 		},
-- 	},
-- 	-- keys = {
-- 	--   {
-- 	--     "<leader>?",
-- 	--     function()
-- 	--       require("which-key").show({ global = false })
-- 	--     end,
-- 	--     desc = "Buffer Local Keymaps (which-key)",
-- 	--   },
-- 	-- },
-- 	config = function(_, opts)
-- 		local wk = require("which-key")
-- 		wk.setup(opts)
-- 		wk.register({
-- 			["<leader>d"] = { name = "Debug" },
-- 			["<leader>b"] = { name = "Buffer" },
-- 			["<leader>h"] = { name = "hop: find word" },
-- 			["<leader>g"] = { name = "git" },
-- 			["<leader>l"] = { name = "LSP" },
-- 			["<leader>f"] = { name = "File" },
-- 		})
-- 	end,
-- }
return {
  'folke/which-key.nvim',
  event = 'VimEnter',
  config = function()
    ---@diagnostic disable-next-line: missing-fields
    require('which-key').setup {
      ---@param ctx { mode: string, operator: string }
      defer = function(ctx)
        if vim.list_contains({ 'd', 'y' }, ctx.operator) then
          return true
        end
        return vim.list_contains({ 'v', '<C-V>', 'V' }, ctx.mode)
      end,
      preset = 'modern',
      show_help = false,
      icons = {
        colors = true,
        keys = {
          Up = '􀄨',
          Down = '􀄩',
          Left = '􀄪',
          Right = '􀄫',
          C = '􀆍',
          M = '􀆕',
          S = '􀆝',
          CR = '􀅇',
          Esc = '􀆧',
          ScrollWheelDown = '󱕐',
          ScrollWheelUp = '󱕑',
          NL = '􀅇',
          BS = '􁂉',
          Space = '󱁐',
          Tab = '􀅂',
        },
      },
    }

    -- Document existing key chains
    require('which-key').add {
      -- { 'g', group = 'Go to', icon = '󰿅' },
      -- { '<leader>a', group = 'Avante', icon = '󰚩' },
      { '<leader>b', group = 'Buffer', icon = '' },
      { '<leader>d', group = 'DAP', icon = '' },
      -- { '<leader>c', group = 'DiffView', icon = '' },
      { '<leader>g', group = 'Git', icon = '' },
      { '<leader>l', group = 'Lsp', mode = 'n', icon = '' },
      -- { '<leader>r', group = 'Overseer tasks', mode = 'n', icon = '󰑮' },
      { '<leader>f', group = 'Find', mode = 'n' },
      { '<leader>t', group = 'Toggle' },
      -- { '<leader>h', group = 'Git Hunk', mode = { 'n', 'v' } },
      -- { '<leader>P', group = 'Picture', icon = '' },
      -- { '<leader>x', group = 'Execute Lua', icon = '', mode = { 'n', 'v' } },
    }
  end,
}
