Presence = require("presence"):setup({
  -- Update activity based on autocmd events (if `false`, map or manually execute `:lua Presence:update()`)
  auto_update       = true,
  -- Editing format string (either string or function(filename: string|nil, buffer: string): string)
  editing_text      = "Editing %s",
  -- Workspace format string (either string or function(git_project_name: string|nil, buffer: string): string)
  workspace_text    = "Working on %s",
  -- Text displayed when hovered over the Neovim image
  neovim_image_text = "The One True Text Editor",
  -- Main image display (either "neovim" or "file")
  main_image        = "neovim",
  -- Use your own Discord application client id (not recommended)
  client_id         = "793271441293967371",
  -- Log messages at or above this level (one of the following: "debug", "info", "warn", "error")
  log_level         = nil,
  -- Number of seconds to debounce TextChanged events (or calls to `:lua Presence:update(<buf>, true)`)
  debounce_timeout  = 15,
})
