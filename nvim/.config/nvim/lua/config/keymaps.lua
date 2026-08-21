-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- Word navigation with Ctrl+Arrow keys
vim.keymap.set("n", "<C-Left>", "b", { desc = "Move backward by word" })
vim.keymap.set("n", "<C-Right>", "w", { desc = "Move forward by word" })
