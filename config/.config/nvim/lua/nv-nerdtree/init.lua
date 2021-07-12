local map = vim.api.nvim_set_keymap
-- Toggle
map('', '<C-b>', ':NERDTreeToggle<CR>', { silent = true })
-- Position Window
vim.g.NERDTreeWinPos = "right"
