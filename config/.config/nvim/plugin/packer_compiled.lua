-- Automatically generated packer.nvim plugin loader code

if vim.api.nvim_call_function('has', {'nvim-0.5'}) ~= 1 then
  vim.api.nvim_command('echohl WarningMsg | echom "Invalid Neovim version for packer.nvim! | echohl None"')
  return
end

vim.api.nvim_command('packadd packer.nvim')

local no_errors, error_msg = pcall(function()

  local time
  local profile_info
  local should_profile = false
  if should_profile then
    local hrtime = vim.loop.hrtime
    profile_info = {}
    time = function(chunk, start)
      if start then
        profile_info[chunk] = hrtime()
      else
        profile_info[chunk] = (hrtime() - profile_info[chunk]) / 1e6
      end
    end
  else
    time = function(chunk, start) end
  end
  
local function save_profiles(threshold)
  local sorted_times = {}
  for chunk_name, time_taken in pairs(profile_info) do
    sorted_times[#sorted_times + 1] = {chunk_name, time_taken}
  end
  table.sort(sorted_times, function(a, b) return a[2] > b[2] end)
  local results = {}
  for i, elem in ipairs(sorted_times) do
    if not threshold or threshold and elem[2] > threshold then
      results[i] = elem[1] .. ' took ' .. elem[2] .. 'ms'
    end
  end

  _G._packer = _G._packer or {}
  _G._packer.profile_output = results
end

time([[Luarocks path setup]], true)
local package_path_str = "/home/piero/.cache/nvim/packer_hererocks/2.0.5/share/lua/5.1/?.lua;/home/piero/.cache/nvim/packer_hererocks/2.0.5/share/lua/5.1/?/init.lua;/home/piero/.cache/nvim/packer_hererocks/2.0.5/lib/luarocks/rocks-5.1/?.lua;/home/piero/.cache/nvim/packer_hererocks/2.0.5/lib/luarocks/rocks-5.1/?/init.lua"
local install_cpath_pattern = "/home/piero/.cache/nvim/packer_hererocks/2.0.5/lib/lua/5.1/?.so"
if not string.find(package.path, package_path_str, 1, true) then
  package.path = package.path .. ';' .. package_path_str
end

if not string.find(package.cpath, install_cpath_pattern, 1, true) then
  package.cpath = package.cpath .. ';' .. install_cpath_pattern
end

time([[Luarocks path setup]], false)
time([[try_loadstring definition]], true)
local function try_loadstring(s, component, name)
  local success, result = pcall(loadstring(s))
  if not success then
    vim.schedule(function()
      vim.api.nvim_notify('packer.nvim: Error running ' .. component .. ' for ' .. name .. ': ' .. result, vim.log.levels.ERROR, {})
    end)
  end
  return result
end

time([[try_loadstring definition]], false)
time([[Defining packer_plugins]], true)
_G.packer_plugins = {
  ["cpbooster.vim"] = {
    loaded = false,
    needs_bufread = false,
    path = "/home/piero/.local/share/nvim/site/pack/packer/opt/cpbooster.vim"
  },
  ["friendly-snippets"] = {
    loaded = true,
    path = "/home/piero/.local/share/nvim/site/pack/packer/start/friendly-snippets"
  },
  ["fzf.vim"] = {
    loaded = true,
    path = "/home/piero/.local/share/nvim/site/pack/packer/start/fzf.vim"
  },
  ["gruvbox-material"] = {
    loaded = true,
    path = "/home/piero/.local/share/nvim/site/pack/packer/start/gruvbox-material"
  },
  indentline = {
    loaded = true,
    path = "/home/piero/.local/share/nvim/site/pack/packer/start/indentline"
  },
  ["markdown-preview.nvim"] = {
    loaded = false,
    needs_bufread = false,
    path = "/home/piero/.local/share/nvim/site/pack/packer/opt/markdown-preview.nvim"
  },
  nerdtree = {
    loaded = true,
    path = "/home/piero/.local/share/nvim/site/pack/packer/start/nerdtree"
  },
  ["nerdtree-git-plugin"] = {
    loaded = true,
    path = "/home/piero/.local/share/nvim/site/pack/packer/start/nerdtree-git-plugin"
  },
  ["nvim-colorizer.lua"] = {
    loaded = true,
    path = "/home/piero/.local/share/nvim/site/pack/packer/start/nvim-colorizer.lua"
  },
  ["nvim-compe"] = {
    loaded = true,
    path = "/home/piero/.local/share/nvim/site/pack/packer/start/nvim-compe"
  },
  ["nvim-lspconfig"] = {
    loaded = true,
    path = "/home/piero/.local/share/nvim/site/pack/packer/start/nvim-lspconfig"
  },
  ["nvim-lspinstall"] = {
    loaded = true,
    path = "/home/piero/.local/share/nvim/site/pack/packer/start/nvim-lspinstall"
  },
  ["nvim-treesitter"] = {
    loaded = true,
    path = "/home/piero/.local/share/nvim/site/pack/packer/start/nvim-treesitter"
  },
  ["onedark.nvim"] = {
    loaded = true,
    path = "/home/piero/.local/share/nvim/site/pack/packer/start/onedark.nvim"
  },
  ["packer.nvim"] = {
    loaded = true,
    path = "/home/piero/.local/share/nvim/site/pack/packer/start/packer.nvim"
  },
  ["plenary.nvim"] = {
    loaded = true,
    path = "/home/piero/.local/share/nvim/site/pack/packer/start/plenary.nvim"
  },
  ["popup.nvim"] = {
    loaded = true,
    path = "/home/piero/.local/share/nvim/site/pack/packer/start/popup.nvim"
  },
  ["presence.nvim"] = {
    loaded = true,
    path = "/home/piero/.local/share/nvim/site/pack/packer/start/presence.nvim"
  },
  ["telescope.nvim"] = {
    loaded = true,
    path = "/home/piero/.local/share/nvim/site/pack/packer/start/telescope.nvim"
  },
  ["tmuxline.vim"] = {
    loaded = true,
    path = "/home/piero/.local/share/nvim/site/pack/packer/start/tmuxline.vim"
  },
  ["vim-airline"] = {
    loaded = true,
    path = "/home/piero/.local/share/nvim/site/pack/packer/start/vim-airline"
  },
  ["vim-airline-themes"] = {
    loaded = true,
    path = "/home/piero/.local/share/nvim/site/pack/packer/start/vim-airline-themes"
  },
  ["vim-commentary"] = {
    loaded = true,
    path = "/home/piero/.local/share/nvim/site/pack/packer/start/vim-commentary"
  },
  ["vim-devicons"] = {
    loaded = true,
    path = "/home/piero/.local/share/nvim/site/pack/packer/start/vim-devicons"
  },
  ["vim-fugitive"] = {
    loaded = true,
    path = "/home/piero/.local/share/nvim/site/pack/packer/start/vim-fugitive"
  },
  ["vim-jsx-pretty"] = {
    loaded = false,
    needs_bufread = true,
    path = "/home/piero/.local/share/nvim/site/pack/packer/opt/vim-jsx-pretty"
  },
  ["vim-nerdtree-syntax-highlight"] = {
    loaded = true,
    path = "/home/piero/.local/share/nvim/site/pack/packer/start/vim-nerdtree-syntax-highlight"
  },
  ["vim-prettier"] = {
    loaded = true,
    path = "/home/piero/.local/share/nvim/site/pack/packer/start/vim-prettier"
  },
  ["vim-surround"] = {
    loaded = true,
    path = "/home/piero/.local/share/nvim/site/pack/packer/start/vim-surround"
  },
  ["vim-vsnip"] = {
    loaded = true,
    path = "/home/piero/.local/share/nvim/site/pack/packer/start/vim-vsnip"
  },
  ["vim-vsnip-integ"] = {
    loaded = true,
    path = "/home/piero/.local/share/nvim/site/pack/packer/start/vim-vsnip-integ"
  },
  ["vim-vue"] = {
    loaded = false,
    needs_bufread = true,
    path = "/home/piero/.local/share/nvim/site/pack/packer/opt/vim-vue"
  },
  ["yats.vim"] = {
    loaded = false,
    needs_bufread = true,
    path = "/home/piero/.local/share/nvim/site/pack/packer/opt/yats.vim"
  }
}

time([[Defining packer_plugins]], false)
vim.cmd [[augroup packer_load_aucmds]]
vim.cmd [[au!]]
  -- Filetype lazy-loads
time([[Defining lazy-load filetype autocommands]], true)
vim.cmd [[au FileType jsx ++once lua require("packer.load")({'vim-jsx-pretty'}, { ft = "jsx" }, _G.packer_plugins)]]
vim.cmd [[au FileType vue ++once lua require("packer.load")({'vim-vue'}, { ft = "vue" }, _G.packer_plugins)]]
vim.cmd [[au FileType javascriptreact ++once lua require("packer.load")({'vim-jsx-pretty'}, { ft = "javascriptreact" }, _G.packer_plugins)]]
vim.cmd [[au FileType typescript ++once lua require("packer.load")({'yats.vim'}, { ft = "typescript" }, _G.packer_plugins)]]
vim.cmd [[au FileType tsx ++once lua require("packer.load")({'vim-jsx-pretty'}, { ft = "tsx" }, _G.packer_plugins)]]
vim.cmd [[au FileType cpp ++once lua require("packer.load")({'cpbooster.vim'}, { ft = "cpp" }, _G.packer_plugins)]]
vim.cmd [[au FileType typescriptreact ++once lua require("packer.load")({'vim-jsx-pretty', 'yats.vim'}, { ft = "typescriptreact" }, _G.packer_plugins)]]
vim.cmd [[au FileType javascript.jsx ++once lua require("packer.load")({'vim-jsx-pretty'}, { ft = "javascript.jsx" }, _G.packer_plugins)]]
vim.cmd [[au FileType typescript.tsx ++once lua require("packer.load")({'vim-jsx-pretty', 'yats.vim'}, { ft = "typescript.tsx" }, _G.packer_plugins)]]
vim.cmd [[au FileType md ++once lua require("packer.load")({'markdown-preview.nvim'}, { ft = "md" }, _G.packer_plugins)]]
time([[Defining lazy-load filetype autocommands]], false)
vim.cmd("augroup END")
vim.cmd [[augroup filetypedetect]]
time([[Sourcing ftdetect script at: /home/piero/.local/share/nvim/site/pack/packer/opt/vim-vue/ftdetect/vue.vim]], true)
vim.cmd [[source /home/piero/.local/share/nvim/site/pack/packer/opt/vim-vue/ftdetect/vue.vim]]
time([[Sourcing ftdetect script at: /home/piero/.local/share/nvim/site/pack/packer/opt/vim-vue/ftdetect/vue.vim]], false)
time([[Sourcing ftdetect script at: /home/piero/.local/share/nvim/site/pack/packer/opt/yats.vim/ftdetect/typescript.vim]], true)
vim.cmd [[source /home/piero/.local/share/nvim/site/pack/packer/opt/yats.vim/ftdetect/typescript.vim]]
time([[Sourcing ftdetect script at: /home/piero/.local/share/nvim/site/pack/packer/opt/yats.vim/ftdetect/typescript.vim]], false)
time([[Sourcing ftdetect script at: /home/piero/.local/share/nvim/site/pack/packer/opt/yats.vim/ftdetect/typescriptreact.vim]], true)
vim.cmd [[source /home/piero/.local/share/nvim/site/pack/packer/opt/yats.vim/ftdetect/typescriptreact.vim]]
time([[Sourcing ftdetect script at: /home/piero/.local/share/nvim/site/pack/packer/opt/yats.vim/ftdetect/typescriptreact.vim]], false)
vim.cmd("augroup END")
if should_profile then save_profiles() end

end)

if not no_errors then
  vim.api.nvim_command('echohl ErrorMsg | echom "Error in packer_compiled: '..error_msg..'" | echom "Please check your config for correctness" | echohl None')
end
