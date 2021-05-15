return {
  filetypes = { 'typescript' },
  init_options = {
    enable = true,
    lint = false,
    unstable = false
  },
  root_dir = require('lspconfig/util').root_pattern('.deno')
}
