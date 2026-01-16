-- Short alias if you like
local map = vim.keymap.set

-- Move current line up and down in normal mode
map("n", "<A-Down>", ":m .+1<CR>==", { silent = true })
map("n", "<A-Up>", ":m .-2<CR>==", { silent = true })

-- Move selected lines up and down in visual mode
map("v", "<A-Down>", ":m '>+1<CR>gv=gv", { silent = true })
map("v", "<A-Up>", ":m '<-2<CR>gv=gv", { silent = true })

-- Select entire buffer
map("n", "<C-a>", "ggVG", { desc = "Select entire buffer" })

-- Save buffer with Ctrl+S
map("n", "<C-s>", "<cmd>w<CR>", { desc = "Save buffer" })
map("i", "<C-s>", "<Esc><cmd>w<CR>", { desc = "Save buffer" })

-- Find and replace
map("n", "<C-f>", function()
	return ":%s/"
end, { expr = true })

-- Move half page down (Ctrl+D behavior, since Ctrl+D is used for multicursor)
map("n", "<C-n>", "<C-d>", { desc = "Move half page down" })
