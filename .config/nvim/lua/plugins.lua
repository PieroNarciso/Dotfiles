-- This file can be loaded by calling `lua require('plugins')` from your init.vim

-- Only required if you have packer configured as `opt`
-- vim.cmd [[packadd packer.nvim]]
-- Only if your version of Neovim doesn't have https://github.com/neovim/neovim/pull/12632 merged
-- vim._update_package_paths()

return require('packer').startup(function()
  -- Packer manager
  use 'wbthomason/packer.nvim'

  -- Utilities
  use 'yggdroot/indentline'  
  use 'tpope/vim-surround'
  use 'tpope/vim-commentary'
  use { 'prettier/vim-prettier', run = 'npm install' }

  -- Integration
  use 'scrooloose/nerdtree'
  use 'xuyuanp/nerdtree-git-plugin'
  use 'junegunn/fzf.vim'

  -- Syntax Hightlighting
  use { 'nvim-treesitter/nvim-treesitter', run = ':TSUpdate' }
  use 'sainnhe/gruvbox-material'

  -- Interface
  use 'vim-airline/vim-airline'
  use 'vim-airline/vim-airline-themes'
  use 'edkolev/tmuxline.vim'
  use 'ryanoasis/vim-devicons'
  use 'tiagofumo/vim-nerdtree-syntax-highlight'

end)
