return {
  "folke/noice.nvim",
  lazy = false,
  dependencies = {
    "MunifTanjim/nui.nvim",
  },
  opts = {
    cmdline = {
      enabled = true,
      view = "cmdline_popup", -- 屏幕居中悬浮窗
    },
    -- 彻底禁用一切非 cmdline 功能，避免任何副作用与侵入性
    messages = { enabled = false },   -- 不劫持 :messages 与原生提示
    popupmenu = { enabled = false },  -- 不劫持菜单，由 blink.cmp 负责
    notify = { enabled = false },     -- 不劫持通知，由 snacks.notifier 负责
    lsp = {
      progress = { enabled = false },
      hover = { enabled = false },
      signature = { enabled = false },
      message = { enabled = false },
      smart_move = { enabled = false },
    },
    presets = {
      bottom_search = false,          -- 搜索 / 也居中显示
      command_palette = false,
      long_message_to_split = false,
      inc_rename = false,
      lsp_doc_border = false,
    },
  },
}
