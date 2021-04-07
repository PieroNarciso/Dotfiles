local set = vim.api.nvim_set_keymap

set('n', '<C-p>', ':Files<CR>', { noremap = true })
set('n', '<Leader>ps', ':Rg<CR>', { noremap = true })
set('n', '<Leader>pb', ':Buffers<CR>', { noremap = true })
