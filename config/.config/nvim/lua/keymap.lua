vim.g.mapleader = " "

local set = vim.api.nvim_set_keymap

-- Unbind some useless/annoying default key bindings
set('n', 'Q', '<Nop>', { noremap = false })

-- Move between vim buffers
set('n', '<Tab>', ':bnext<CR>', { noremap = true })
set('n', '<S-Tab>', ':bprevious<CR>', { noremap = true })

-- Visual map for maintain Visual Mode after shifting > and <
set('v', '<', '<gv', {})
set('v', '>', '>gv', {})

-- Close current buffer
set('n', '<Leader>cb', ':bdelete<CR>', {})

-- Select all buffer
set('n', '<Leader>a', 'ggVG', {})

-- Search mapping: Center next and previous search
set('n', 'n', 'nzzzv', { noremap = true })
set('n', 'N', 'Nzzzv', { noremap = true })
