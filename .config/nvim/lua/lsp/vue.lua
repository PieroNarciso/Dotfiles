return {
  filetypes = { "vue" },
  init_options = {
    config = {
      css = {},
      emmet = {},
      html = {
        suggest = {}
      },
      javascript = {
        format = {}
      },
      stylusSupremacy = {},
      typescript = {
        format = {}
      },
      vetur = {
        completion = {
          autoImport = true,
          tagCasing = "kebab",
          useScaffoldSnippets = false
        },
        format = {
          defaultFormatter = {
            js = "none",
            ts = "none"
          },
          defaultFormatterOptions = {},
          scriptInitialIndent = false,
          styleInitialIndent = false
        },
        experimental = {
          templateInterpolationService = true
        },
        useWorkspaceDependencies = false,
        validation = {
          templateProps = true,
          script = true,
          style = true,
          template = true,
          interpolation = true,
        }
      }
    }
  },
  root_dir = require('lspconfig/util').root_pattern("package.json", "vue.config.js")
}
