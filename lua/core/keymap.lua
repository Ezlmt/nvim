local map = vim.keymap.set
vim.g.mapleader = " "
vim.g.maplocalleader = ","

map("i", "jk", "<Esc>" , { silent = true})

map("i", "<C-h>", "<Left>")
map("i", "<C-j>", "<Down>")
map("i", "<C-k>", "<Up>")
map("i", "<C-l>", "<Right>")

map("n", "<C-h>", "<C-w>h")
map("n", "<C-j>", "<C-w>j")
map("n", "<C-k>", "<C-w>k")
map("n", "<C-l>", "<C-w>l")

map({"n", "x", "o"}, "<S-H>", "^", {desc = "Start of line"})
map({"n", "x", "o"}, "<S-L>", "$", {desc = "End of line"})
