return {
  "akinsho/toggleterm.nvim",
  version = "*",                    -- 跟随任意新版本
  opts = {
    open_mapping = [[<C-\>]],       -- 手动开关键（Ctrl+\）
    direction = "float",            -- 默认浮窗，可改 "horizontal" / "vertical"
    float_opts = { border = "rounded" },
    -- 其它默认值保持不变即可
  },

  -- 一些常用快捷键示范
  keys = {
    -- 1) 随处 Ctrl-\ 开/关浮窗终端
    { "<leader>tt", "<Cmd>ToggleTerm<CR>", mode = { "n", "t" }, desc = "ToggleTerm" },
  },
}
