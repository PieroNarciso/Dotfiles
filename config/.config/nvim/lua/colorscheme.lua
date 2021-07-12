-- Colorscheme
vim.o.termguicolors = true

vim.g.gruvbox_material_palette = "original"
vim.g.gruvbox_material_transparent_background = 1
vim.g.gruvbox_material_visual = "reverse"
vim.g.gruvbox_material_better_performance = 1

vim.cmd('highlight Normal guibg=NONE ctermbg=NONE')
vim.cmd('colorscheme gruvbox-material')
