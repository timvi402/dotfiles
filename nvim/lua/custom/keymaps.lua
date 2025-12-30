-- Short alias if you like
local map = vim.keymap.set

-- Move current line up and down in normal mode
map('n', '<A-Down>', ':m .+1<CR>==', { silent = true })
map('n', '<A-Up>', ':m .-2<CR>==', { silent = true })

-- Move selected lines up and down in visual mode
map('v', '<A-Down>', ":m '>+1<CR>gv=gv", { silent = true })
map('v', '<A-Up>', ":m '<-2<CR>gv=gv", { silent = true })

-- Select entire buffer
map('n', '<C-a>', 'ggVG', { desc = 'Select entire buffer' })
