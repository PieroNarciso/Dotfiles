local function prettier()
  return {
    exe = "prettier",
    args = {
      "--stdin-filepath",
      vim.fn.fnameescape(vim.api.nvim_buf_get_name(0)),
      '--single-quote'
    },
    stdin = true
  }
end

require('formatter').setup{
  filetype = {
    javascript = { prettier },
    typescript = { prettier },
    typescriptreact = { prettier },
  }
}

local set = vim.api.nvim_set_keymap

set('n', '<leader>ft', ':Format<CR>', { noremap = false, silent = true })
