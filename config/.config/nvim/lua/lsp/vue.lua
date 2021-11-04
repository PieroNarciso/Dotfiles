return {
  filetypes = { "vue" },
  root_dir = require('lspconfig/util').root_pattern("package.json", "vue.config.js")
}
