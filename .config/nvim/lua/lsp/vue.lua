return {
  filetypes = { 'vue' },
  init_options = {
    vetur =  {
      completion = {
        autoImport = true,
        tagCasing = 'kebab',
        useScaffoldSnippets = true
      },
      experimental = {
        templateInterpolationService = true
      },
      validation = {
        interpolation = true,
        templateProps = true
      }
    }
  },
  root_dir = require('lspconfig/util').root_pattern("package.json", "vue.config.js")
}
