local map = vim.keymap.set
vim.g.mapleader = " "
vim.g.maplocalleader = ","

map("i", "jk", "<Esc>" , { silent = true})

map("i", "<C-h>", "<Left>")
map("i", "<C-j>", "<Down>")
map("i", "<C-k>", "<Up>")
map("i", "<C-l>", "<Right>")
