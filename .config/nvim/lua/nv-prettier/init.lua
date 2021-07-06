-- Change the mapping Prettier
vim.cmd("nmap <Leader>pr <Plug>(PrettierAsync)")

-- Max line length that prettier will wrap on: a number or 'auto' (use
-- textwidth).
-- default: 'auto'
vim.cmd("let g:prettier#config#print_width = 'auto'")

-- number of spaces per indentation level: a number or 'auto' (use
-- softtabstop)
-- default: 'auto'
vim.cmd("let g:prettier#config#tab_width = 'auto'")

-- Use single quotes
vim.cmd("let g:prettier#config#single_quote = 'true'")

-- use tabs instead of spaces: true, false, or auto (use the expandtab setting).
-- default: 'auto'
vim.cmd("let g:prettier#config#use_tabs = 'auto'")

-- flow|babylon|typescript|css|less|scss|json|graphql|markdown or empty string
-- (let prettier choose).
-- default: ''
vim.cmd("let g:prettier#config#parser = ''")

-- cli-override|file-override|prefer-file
-- default: 'file-override'
vim.cmd("let g:prettier#config#config_precedence = 'file-override'")

-- always|never|preserve
-- default: 'preserve'
vim.cmd("let g:prettier#config#prose_wrap = 'preserve'")

-- css|strict|ignore
-- default: 'css'
vim.cmd("let g:prettier#config#html_whitespace_sensitivity = 'css'")

-- false|true
-- default: 'false'
vim.cmd("let g:prettier#config#require_pragma = 'false'")

-- Define the flavor of line endings
-- lf|crlf|cr|all
-- defaut: 'lf'
vim.cmd("let g:prettier#config#end_of_line = get(g:, 'prettier#config#end_of_line', 'lf')")

-- Enable auto formatting of files that have '@format' or @'prettier' tag
vim.cmd("let g:prettier#autoformat = 0")

-- Allow auto formatting for files without '@format' or '@prettier' tag
vim.cmd("let g:prettier#autoformat_require_pragman = 0")
