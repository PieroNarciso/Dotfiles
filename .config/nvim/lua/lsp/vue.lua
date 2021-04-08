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
  }
}
