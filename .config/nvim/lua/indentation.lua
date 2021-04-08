-- TODO filetype is not set at load
local utils = require('utils')

vim.o.filetype = 'on'
vim.bo.autoindent = true
vim.bo.smartindent = true

local OPTIONS = {
	shiftwidth = 4,
	tabstop = 4,
	softtabstop = 2,
	expandtab = false,
}


-- Tab Configuration
if (vim.bo.filetype == 'lua') then
	OPTIONS = {
		shiftwidth = 2,
		tabstop = 2,
		softtabstop = 2,
		expandtab = true,
	}
elseif (vim.bo.filetype == 'python') then
	OPTIONS = {
		shiftwidth = 2,
		tabstop = 2,
		softtabstop = 2,
		expandtab = true,
	}
elseif (vim.bo.filetype == 'html') then
	OPTIONS = {
		shiftwidth = 2,
		tabstop = 2,
		softtabstop = 2,
		expandtab = true,
	}
else
end

utils.set_buf_options(OPTIONS)
