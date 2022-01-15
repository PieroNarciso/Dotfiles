---------------------------------------------
-- Awesome theme which follows xrdb config --
--   by Yauhen Kirylau                    --
---------------------------------------------

local theme_assets = require("beautiful.theme_assets")
local xresources = require("beautiful.xresources")
local dpi = xresources.apply_dpi
local xrdb = xresources.get_current_theme()
local gfs = require("gears.filesystem")
local themes_path = gfs.get_themes_dir()

-- inherit default theme
local theme = dofile(themes_path.."default/theme.lua")

local colors = {
  background = xrdb.color0,
  foreground = xrdb.color15,
  black = xrdb.color0,
  bblack = xrdb.color8,
  red = xrdb.color1,
  bred = xrdb.color9,
  green = xrdb.color2,
  bgreen = xrdb.color10,
  yellow = xrdb.color3,
  byellow = xrdb.color11,
  blue = xrdb.color4,
  bblue = xrdb.color12,
  mangenta = xrdb.color5,
  bmangenta = xrdb.color13,
  cyan = xrdb.color6,
  bcyan = xrdb.color14,
  white = xrdb.color7,
  bwhite = xrdb.color15,
}

-- load vector assets' generators for this theme

theme.font          = "Font Awesome 5 Free 8"

theme.bg_normal     = colors.background
theme.bg_focus      = colors.bblue
theme.bg_urgent     = colors.bred
theme.bg_minimize   = colors.bblack
theme.bg_systray    = colors.background

theme.fg_normal     = colors.foreground
theme.fg_focus      = theme.bg_normal
theme.fg_urgent     = theme.bg_normal
theme.fg_minimize   = theme.bg_normal

theme.useless_gap   = dpi(3)
theme.border_width  = dpi(2)
theme.border_normal = colors.bblack
theme.border_focus  = colors.blue
theme.border_marked = colors.bgreen

-- There are other variable sets
-- overriding the default one when
-- defined, the sets are:
-- taglist_[bg|fg]_[focus|urgent|occupied|empty|volatile]
-- tasklist_[bg|fg]_[focus|urgent]
-- titlebar_[bg|fg]_[normal|focus]
-- tooltip_[font|opacity|fg_color|bg_color|border_width|border_color]
-- mouse_finder_[color|timeout|animate_timeout|radius|factor]
-- Example:
--theme.taglist_bg_focus = "#ff0000"

theme.taglist_bg_occupied = theme.bg_normal
theme.taglist_fg_occupied = theme.fg_normal

theme.taglist_bg_focus = theme.bg_focus
theme.taglist_fg_focus = theme.fg_focus

theme.taglist_spacing = dpi(0)
theme.taglist_font = "Font Awesome 5 Free 10"

theme.tooltip_fg = theme.fg_normal
theme.tooltip_bg = theme.bg_normal

-- Systray
theme.systray_icon_spacing = dpi(3)

-- Variables set for theming the menu:
-- menu_[bg|fg]_[normal|focus]
-- menu_[border_color|border_width]
theme.menu_submenu_icon = themes_path.."default/submenu.png"
theme.menu_height = dpi(16)
theme.menu_width  = dpi(100)

-- You can add as many variables as
-- you wish and access them by using
-- beautiful.variable in your rc.lua
--theme.bg_widget = "#cc0000"

-- Recolor Layout icons:
theme = theme_assets.recolor_layout(theme, theme.fg_normal)

-- Recolor titlebar icons:
--
local function darker(color_value, darker_n)
    local result = "#"
    for s in color_value:gmatch("[a-fA-F0-9][a-fA-F0-9]") do
        local bg_numeric_value = tonumber("0x"..s) - darker_n
        if bg_numeric_value < 0 then bg_numeric_value = 0 end
        if bg_numeric_value > 255 then bg_numeric_value = 255 end
        result = result .. string.format("%2.2x", bg_numeric_value)
    end
    return result
end
theme = theme_assets.recolor_titlebar(
    theme, theme.fg_normal, "normal"
)
theme = theme_assets.recolor_titlebar(
    theme, darker(theme.fg_normal, -60), "normal", "hover"
)
theme = theme_assets.recolor_titlebar(
    theme, xrdb.color1, "normal", "press"
)
theme = theme_assets.recolor_titlebar(
    theme, theme.fg_focus, "focus"
)
theme = theme_assets.recolor_titlebar(
    theme, darker(theme.fg_focus, -60), "focus", "hover"
)
theme = theme_assets.recolor_titlebar(
    theme, xrdb.color1, "focus", "press"
)

-- Define the icon theme for application icons. If not set then the icons
-- from /usr/share/icons and /usr/share/icons/hicolor will be used.
theme.icon_theme = nil

-- Generate Awesome icon:
theme.awesome_icon = theme_assets.awesome_icon(
    theme.menu_height, theme.bg_focus, theme.fg_focus
)

-- Generate taglist squares:
local taglist_square_size = dpi(4)
theme.taglist_squares_sel = theme_assets.taglist_squares_sel(
    taglist_square_size, theme.fg_normal
)
theme.taglist_squares_unsel = theme_assets.taglist_squares_unsel(
    taglist_square_size, theme.fg_normal
)

theme.wallpaper = string.format('%s/.local/share/wallpapers/city.png', os.getenv('HOME'))

return theme

-- vim: filetype=lua:expandtab:shiftwidth=4:tabstop=8:softtabstop=4:textwidth=80
