local api = vim.api

local M = {}

function M.set_buf_options(options)
    for opt, val in pairs(options) do
	api.nvim_buf_set_option(0, opt, val)
    end
end

return M
