require'nvim-treesitter.configs'.setup {
  highlight = {
    enable = true
  },
  indent = {
    enable = true,
    disable = { 'lua', 'typescript' }
  },
  context_commentstring = {
    enable = true
  }
}
