if not vim.g.neovide then
  return
end


vim.o.guifont = "Maple Mono NF CN"
vim.g.neovide_no_idle = true
-- vim.g.neovide_fullscreen = true
vim.g.neovide_macos_simple_fullscreen = true
-- vim.g.neovide_remember_window_size = true
vim.g.neovide_input_macos_alt_meta = true
vim.g.neovide_scale_factor = 1.00
vim.g.neovide_padding_top    = 8
vim.g.neovide_padding_bottom = 8
vim.g.neovide_padding_left   = 12
vim.g.neovide_padding_right  = 12

vim.g.neovide_refresh_rate       = 144
vim.g.neovide_refresh_rate_idle  = 30
vim.g.neovide_cursor_animation_length = 0.05
vim.g.neovide_cursor_vfx_mode         = "railgun"

-- vim.g.neovide_opacity = 0.0
vim.g.neovide_normal_opacity = 0.8
vim.g.transparency = 0.8
vim.g.neovide_window_blurred = true

local function change_scale(delta)
  vim.g.neovide_scale_factor = vim.g.neovide_scale_factor * delta
end
vim.keymap.set("n", "<C-=>", function() change_scale(1.25) end, { desc = "放大" })
vim.keymap.set("n", "<C-->", function() change_scale(1/1.25) end, { desc = "缩小" })


