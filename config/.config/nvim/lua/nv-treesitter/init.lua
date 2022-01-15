require'nvim-treesitter.configs'.setup {
  highlight = {
    enable = true
  },
  indent = {
    enable = true,
    disable = { 'lua', 'typescript', 'cpp', 'yaml', 'python' }
  },
  context_commentstring = {
    enable = true
  }
}
