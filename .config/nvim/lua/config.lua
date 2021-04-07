-- Default configuration
vim.o.compatible = false -- Enable Vim functionalities
vim.bo.autoread = true
vim.o.background = 'dark'
vim.o.backspace = 'indent,eol,start'
vim.o.belloff = 'all'
vim.cmd('filetype plugin on')
vim.cmd('filetype indent on')
vim.cmd('filetype on')
 
-- Show line numbers and enable relative line numbering mode.
vim.wo.number = true
vim.wo.relativenumber = true

-- Always show the status line at the bottom even if you only have one window open.
vim.o.laststatus = 2

-- No show --INSERT--, etc because of lightline
vim.o.showmode = true

-- Set cursor to block
vim.o.guicursor = ''

-- Enable color column to 80
vim.wo.colorcolumn = '80'

-- Set off set for scrolling
vim.o.scrolloff = 8

-- Hidden buffers
vim.o.hidden = true

-- Case sensitive at search
vim.o.ignorecase = true
vim.o.smartcase = true

-- Enable searching as typing
vim.o.incsearch = true
-- Disable highlighting searching
vim.o.hlsearch = false

-- Mouse support
vim.o.mouse = 'a'

-- Clipboard support
vim.o.clipboard = 'unnamedplus'

-- Indentation
vim.o.filetype = 'on'
vim.bo.autoindent = true
vim.bo.smartindent = true

vim.api.nvim_exec(
[[
	autocmd Filetype python setlocal sw=4 ts=4 sts=4 expandtab
	autocmd Filetype html setlocal sw=2 ts=2 sts=2 expandtab
	autocmd Filetype vue setlocal sw=2 ts=2 sts=2 expandtab
	autocmd Filetype lua setlocal sw=2 ts=2 sts=2 expandtab
	autocmd Filetype css setlocal sw=2 ts=2 sts=2 expandtab
	autocmd Filetype javascript setlocal sw=2 ts=2 sts=2 expandtab
	autocmd Filetype javascriptreact setlocal sw=2 ts=2 sts=2 expandtab
	autocmd Filetype javascript.jsx setlocal sw=2 ts=2 sts=2 expandtab
	autocmd Filetype typescript setlocal sw=2 ts=2 sts=2 expandtab
	autocmd Filetype typescriptreact setlocal sw=2 ts=2 sts=2 expandtab
	autocmd Filetype mason setlocal sw=2 ts=4 sts=2 expandtab
	autocmd Filetype json setlocal sw=2 ts=4 sts=2 expandtab
	autocmd Filetype make setloc sw=4 ts=4 sts=4 noexpandtab
]],
true)

-- Colorscheme
vim.o.termguicolors = true
vim.cmd('highlight Normal guibg=NONE ctermbg=NONE')
vim.cmd('let g:gruvbox_material_palette = "original"')
vim.cmd('let g:gruvbox_material_transparent_background = 1')
vim.cmd('let g:gruvbox_material_visual = "reverse"')
vim.cmd('let g:gruvbox_material_better_performance = 1')
vim.cmd('colorscheme gruvbox-material')