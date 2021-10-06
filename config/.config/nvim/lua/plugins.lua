-- This file can be loaded by calling `lua require('plugins')` from your init.vim
--

-- Only required if you have packer configured as `opt`
-- vim.cmd [[packadd packer.nvim]]
-- Only if your version of Neovim doesn't have https://github.com/neovim/neovim/pull/12632 merged
-- vim._update_package_paths()

return require('packer').startup(function(use)
  -- Packer manager
  use 'wbthomason/packer.nvim'

  -- Utilities
  use 'lukas-reineke/indent-blankline.nvim'
  use 'tpope/vim-surround'
  use 'tpope/vim-commentary'
  use 'JoosepAlviste/nvim-ts-context-commentstring'
  use { 'prettier/vim-prettier', run = 'npm install' }
  use 'andweeb/presence.nvim'
  use 'tpope/vim-fugitive'
  use 'windwp/nvim-autopairs'

  -- Competitive programming
  use { 'searleser97/cpbooster.vim', ft = {'cpp'} }

  -- Integration
  use 'scrooloose/nerdtree'
  use 'xuyuanp/nerdtree-git-plugin'
  use 'junegunn/fzf.vim'
  -- use {
  --   'nvim-telescope/telescope.nvim',
  --   requires = {{'nvim-lua/popup.nvim'}, {'nvim-lua/plenary.nvim'}}
  -- }

  -- Completion
  use 'hrsh7th/nvim-compe'
  use 'rafamadriz/friendly-snippets'
  use 'hrsh7th/vim-vsnip'
  use 'hrsh7th/vim-vsnip-integ'

  -- Language support
  use 'neovim/nvim-lspconfig'
  use 'kabouzeid/nvim-lspinstall'

  -- Syntax Highlighting
  use { 'nvim-treesitter/nvim-treesitter', run = ':TSUpdate' }
  use 'tiagofumo/vim-nerdtree-syntax-highlight'
  use 'norcalli/nvim-colorizer.lua'
  use { 'posva/vim-vue', ft = {'vue'} }

  -- Interface
  use 'vim-airline/vim-airline'
  use 'vim-airline/vim-airline-themes'
  use 'edkolev/tmuxline.vim'
  use 'ryanoasis/vim-devicons'

  -- Colorscheme
  use 'sainnhe/gruvbox-material'

end)
