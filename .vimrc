" Comments in Vimscript start with a `"`.

" If you open this file in Vim, it'll be syntax highlighted for you.

" Vim is based on Vi. Setting `nocompatible` switches from the default
" Vi-compatibility mode and enables useful Vim functionality. This
" configuration option turns out not to be necessary for the file named
" '~/.vimrc', because Vim automatically enters nocompatible mode if that file
" is present. But we're including it here just in case this config file is
" loaded some other way (e.g. saved as `foo`, and then Vim started with
" `vim -u foo`).
set nocompatible

" Turn on syntax highlighting.
syntax on

" Disable the default Vim startup message.
set shortmess+=I

" Show line numbers.
set number

" This enables relative line numbering mode. With both number and
" relativenumber enabled, the current line shows the true line number, while
" all other lines (above and below) are numbered relative to the current line.
" This is useful because you can tell, at a glance, what count is needed to
" jump up or down to a particular line, by {count}k to go up or {count}j to go
" down.
set relativenumber

" Always show the status line at the bottom, even if you only have one window open.
set laststatus=2

" No show --INSERT--, etc because or lightline
set noshowmode

" The backspace key has slightly unintuitive behavior by default. For example,
" by default, you can't backspace before the insertion point set with 'i'.
" This configuration makes backspace behave more reasonably, in that you can
" backspace over anything.
set backspace=indent,eol,start

" Tab configuration
set softtabstop=4
set shiftwidth=4
set autoindent
set noexpandtab
set smartindent
" set cindent

" Indentation configuration by filetype
autocmd Filetype python setlocal sw=4 ts=4 sts=4 expandtab
autocmd Filetype html setlocal sw=2 ts=2 sts=2 expandtab
autocmd Filetype vue setlocal sw=2 ts=2 sts=2 expandtab
autocmd Filetype javascript setlocal sw=2 ts=2 sts=2 expandtab
autocmd Filetype typescript setlocal sw=4 ts=4 sts=4 expandtab
autocmd Filetype mason setlocal sw=2 ts=4 sts=2 expandtab
autocmd Filetype json setlocal sw=2 ts=4 sts=2 expandtab
autocmd Filetype make setloc sw=4 ts=4 sts=4 noexpandtab


" By default, Vim doesn't let you hide a buffer (i.e. have a buffer that isn't
" shown in any window) that has unsaved changes. This is to prevent you from "
" forgetting about unsaved changes and then quitting e.g. via `:qa!`. We find
" hidden buffers helpful enough to disable this protection. See `:help hidden`
" for more information on this.
set hidden

" This setting makes search case-insensitive when all characters in the string
" being searched are lowercase. However, the search becomes case-sensitive if
" it contains any capital letters. This makes searching more convenient.
set ignorecase
set smartcase

" Enable searching as you type, rather than waiting till you press enter.
set incsearch
" Enable highlighting searching
" set hlsearch

" Unbind some useless/annoying default key bindings.
nmap Q <Nop> " 'Q' in normal mode enters Ex mode. You almost never want this.

" Disable audible bell because it's annoying.
set noerrorbells visualbell t_vb=

" Enable mouse support. You should avoid relying on this too much, but it can
" sometimes be convenient.
set mouse+=a

" Try to prevent bad habits like using the arrow keys for movement. This is
" not the only possible bad habit. For example, holding down the h/j/k/l keys
" for movement, rather than using more efficient movement commands, is also a
" bad habit. The former is enforceable through a .vimrc, while we don't know
" how to prevent the latter.
" Do this in normal mode...
nnoremap <Left>  :echoe "Use h"<CR>
nnoremap <Right> :echoe "Use l"<CR>
nnoremap <Up>    :echoe "Use k"<CR>
nnoremap <Down>  :echoe "Use j"<CR>
" ...and in insert mode
inoremap <Left>  <ESC>:echoe "Use h"<CR>
inoremap <Right> <ESC>:echoe "Use l"<CR>
inoremap <Up>    <ESC>:echoe "Use k"<CR>
inoremap <Down>  <ESC>:echoe "Use j"<CR>

" Vmap for maintain Visual Mode after shifting > and <
vmap < <gv
vmap > >gv

" Search mapping: These will make it so that going to the next one in a
" search will center on the line it's found in.
nnoremap n nzzzv
nnoremap N Nzzzv

call plug#begin('~/.vim/plugged')
    "" Utilities
    Plug 'yggdroot/indentline'
    Plug 'tpope/vim-surround'
    Plug 'easymotion/vim-easymotion'
    Plug 'chiel92/vim-autoformat'
    Plug 'tpope/vim-commentary'
    " Plug 'jiangmiao/auto-pairs'

    "" Integration
    Plug 'scrooloose/nerdtree' 
    Plug 'xuyuanp/nerdtree-git-plugin'
    Plug 'ctrlpvim/ctrlp.vim'

    "" Language support
    Plug 'neoclide/coc.nvim', {'branch': 'release'}
    Plug 'posva/vim-vue'

    "" Syntax Highlighting
    Plug 'octol/vim-cpp-enhanced-highlight'

    "" Interface
    Plug 'vim-airline/vim-airline'
    Plug 'vim-airline/vim-airline-themes'
    Plug 'edkolev/tmuxline.vim'
call plug#end()


" Importing extra files
source $HOME/.vim/plugins/coc.vim
source $HOME/.vim/plugins/easymotion.vim
source $HOME/.vim/plugins/nerdtree.vim
source $HOME/.vim/plugins/airline.vim

" Colorscheme
set background=dark
colorscheme gruvbox
