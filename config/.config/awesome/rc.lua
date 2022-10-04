-- If LuaRocks is installed, make sure that packages installed through it are
-- found (e.g. lgi). If LuaRocks is not installed, do nothing.
pcall(require, "luarocks.loader")

-- Standard awesome library
local gears = require("gears")
local awful = require("awful")
require("awful.autofocus")
-- Widget and layout library
local wibox = require("wibox")
-- Theme handling library
local beautiful = require("beautiful")
-- Notification library
-- local naughty = require("naughty")
local menubar = require("menubar")
local hotkeys_popup = require("awful.hotkeys_popup")
-- Enable hotkeys help widget for VIM and other apps
-- when client with a matching name is opened:
require("awful.hotkeys_popup.keys")

-- {{{ Error handling
-- Check if awesome encountered an error during startup and fell back to
-- another config (This code will only ever execute for the fallback config)
-- if awesome.startup_errors then
--     naughty.notify({ preset = naughty.config.presets.critical,
--                      title = "Oops, there were errors during startup!",
--                      text = awesome.startup_errors })
-- end

-- Handle runtime errors after startup
do
    local in_error = false
    awesome.connect_signal("debug::error", function (err)
        -- Make sure we don't go into an endless error loop
        if in_error then return end
        in_error = true

        -- naughty.notify({ preset = naughty.config.presets.critical,
        --                  title = "Oops, an error happened!",
        --                  text = tostring(err) })
        in_error = false
    end)
end
-- }}}

-- {{{ Variable definitions
-- Themes define colours, icons, font and wallpapers.
local theme_path = string.format("%s/.config/awesome/themes/%s/theme.lua", os.getenv("HOME"), "xresources")
beautiful.init(theme_path)

-- This is used later as the default terminal and editor to run.
terminal = "alacritty"
editor = os.getenv("EDITOR") or "nvim"
editor_cmd = terminal .. " -e " .. editor

-- Default modkey.
-- Usually, Mod4 is the key with a logo between Control and Alt.
-- If you do not like this or do not have such a key,
-- I suggest you to remap Mod4 to another key using xmodmap or other tools.
-- However, you can use another modifier like Mod1, but it may interact with others.
modkey = "Mod4"

-- Table of layouts to cover with awful.layout.inc, order matters.
awful.layout.layouts = {
    awful.layout.suit.tile,
    -- awful.layout.suit.tile.left,
    awful.layout.suit.tile.bottom,
    -- awful.layout.suit.tile.top,
    -- awful.layout.suit.fair,
    -- awful.layout.suit.fair.horizontal,
    -- awful.layout.suit.spiral,
    -- awful.layout.suit.spiral.dwindle,
    -- awful.layout.suit.max,
    -- awful.layout.suit.max.fullscreen,
    -- awful.layout.suit.magnifier,
    -- awful.layout.suit.corner.nw,
    -- awful.layout.suit.corner.ne,
    -- awful.layout.suit.corner.sw,
    -- awful.layout.suit.corner.se,
    awful.layout.suit.floating,
}
-- }}}

-- {{{ Menu
-- Create a launcher widget and a main menu
myawesomemenu = {
   { "hotkeys", function() hotkeys_popup.show_help(nil, awful.screen.focused()) end },
   { "manual", terminal .. " -e man awesome" },
   { "edit config", editor_cmd .. " " .. awesome.conffile },
   { "restart", awesome.restart },
   { "quit", function() awesome.quit() end },
}

mymainmenu = awful.menu({ items = { { "awesome", myawesomemenu, beautiful.awesome_icon },
                                    { "open terminal", terminal }
                                  }
                        })

mylauncher = awful.widget.launcher({ image = beautiful.awesome_icon,
                                     menu = mymainmenu })

-- Menubar configuration
menubar.utils.terminal = terminal -- Set the terminal for applications that require it
-- }}}


-- {{{ Wibar

-- Create a wibox for each screen and add it
local taglist_buttons = gears.table.join(
                    awful.button({ }, 1, function(t) t:view_only() end),
                    awful.button({ modkey }, 1, function(t)
                                              if client.focus then
                                                  client.focus:move_to_tag(t)
                                              end
                                          end),
                    awful.button({ }, 3, awful.tag.viewtoggle),
                    awful.button({ modkey }, 3, function(t)
                                              if client.focus then
                                                  client.focus:toggle_tag(t)
                                              end
                                          end),
                    awful.button({ }, 4, function(t) awful.tag.viewnext(t.screen) end),
                    awful.button({ }, 5, function(t) awful.tag.viewprev(t.screen) end)
                )

local tasklist_buttons = gears.table.join(
                     awful.button({ }, 1, function (c)
                                              if c == client.focus then
                                                  c.minimized = true
                                              else
                                                  c:emit_signal(
                                                      "request::activate",
                                                      "tasklist",
                                                      {raise = true}
                                                  )
                                              end
                                          end),
                     awful.button({ }, 3, function()
                                              awful.menu.client_list({ theme = { width = 250 } })
                                          end),
                     awful.button({ }, 4, function ()
                                              awful.client.focus.byidx(1)
                                          end),
                     awful.button({ }, 5, function ()
                                              awful.client.focus.byidx(-1)
                                          end))

local function set_wallpaper(s)
    -- Wallpaper
    if beautiful.wallpaper then
        local wallpaper = beautiful.wallpaper
        -- If wallpaper is a function, call it with the screen
        if type(wallpaper) == "function" then
            wallpaper = wallpaper(s)
        end
        gears.wallpaper.maximized(wallpaper, s, true)
    end
end

-- Re-set wallpaper when a screen's geometry changes (e.g. different resolution)
screen.connect_signal("property::geometry", set_wallpaper)

-- local TAGS = { "", "", "", "", "", "", "", "", "" , "" }
local TAGS = { "1: ", "2: ", "3: ", "4: ", "5: ", "6: ", "7: ", "8: ", "9: " , "10: " }
local vicious = require('vicious')
local xresources = require("beautiful.xresources")
local dpi = xresources.apply_dpi
local xrdb = xresources.get_current_theme()

local colors = {
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



-- Drive space Widget
local drivewidgettext = wibox.widget.textbox()
vicious.register(drivewidgettext, vicious.widgets.fs, " ${/home avail_gb} GB", 100)
local drivewidget = wibox.widget {
  {
    widget = wibox.container.background,
    fg = colors.byellow,
    drivewidgettext
  },
  bottom = dpi(2),
  color = colors.byellow,
  widget = wibox.container.margin,
}

-- Mem Widget
local memwidgettext = wibox.widget.textbox()
vicious.cache(vicious.widgets.mem)
vicious.register(memwidgettext, vicious.widgets.mem,
  ' $1%',
13)
local memwidget = {
  {
    widget = wibox.container.background,
    fg = colors.bblue,
    memwidgettext,
  },
  color = colors.bblue,
  bottom = dpi(2),
  widget = wibox.container.margin,
}

-- CPU Widget
local cpuwidgettext = wibox.widget.textbox()
vicious.register(cpuwidgettext, vicious.widgets.cpu, " $1%", 7)
local cpuwidget = {
  {
    widget = wibox.container.background,
    fg = colors.bmangenta,
    cpuwidgettext,
  },
  color = colors.bmangenta,
  bottom = dpi(2),
  widget = wibox.container.margin,
}

-- Keyboard map indicator and switcher
local keyboardlayoutwidget = wibox.widget {
  {
    {
      wibox.widget.textbox(" "),
      awful.widget.keyboardlayout(),
      layout = wibox.layout.align.horizontal,
    },
    widget = wibox.container.background,
    fg = colors.bcyan
  },
  color = colors.bcyan,
  bottom = dpi(2),
  widget = wibox.container.margin,
}

-- Create a textclock widget
local textclocktext = wibox.widget.textclock()
local month_calendar = awful.widget.calendar_popup.month()
month_calendar:attach(textclocktext, "tr", { on_hover = false })
local textclockwidget = {
  {
    widget = wibox.container.background,
    fg = colors.bgreen,
    textclocktext,
  },
  color = colors.bgreen,
  bottom = dpi(2),
  widget = wibox.container.margin,
}

-- Systray widget
local systray = wibox.widget.systray()
systray:set_base_size(dpi(18))
local systraywidget = {
  systray,
  bottom = dpi(2),
  widget = wibox.container.margin,
}

awful.screen.connect_for_each_screen(function(s)
    -- Wallpaper
    set_wallpaper(s)

    -- Each screen has its own tag table.
    awful.tag(TAGS, s, awful.layout.layouts[1])

    -- Create a promptbox for each screen
    s.mypromptbox = awful.widget.prompt()
    -- Create an imagebox widget which will contain an icon indicating which layout we're using.
    -- We need one layoutbox per screen.
    s.mylayoutbox = awful.widget.layoutbox(s)
    s.mylayoutbox:buttons(gears.table.join(
                           awful.button({ }, 1, function () awful.layout.inc( 1) end),
                           awful.button({ }, 3, function () awful.layout.inc(-1) end),
                           awful.button({ }, 4, function () awful.layout.inc( 1) end),
                           awful.button({ }, 5, function () awful.layout.inc(-1) end)))
    -- Create a taglist widget
    s.mytaglist = awful.widget.taglist {
        screen  = s,
        filter  = awful.widget.taglist.filter.noempty,
        buttons = taglist_buttons,
        widget_template = {
          {
            {
              {
                {
                  {
                    id = 'text_role',
                    widget = wibox.widget.textbox,
                  },
                  left = dpi(0),
                  widget = wibox.container.margin
                },
                widget = wibox.layout.align.horizontal,
              },
              bottom  = dpi(2),
              color = colors.bblack,
              widget = wibox.container.margin,
            },
            left = dpi(5),
            right = dpi(5),
            widget = wibox.container.margin,
          },
          id = 'background_role',
          widget = wibox.container.background,
          -- Index label
        }
    }

    -- Create a tasklist widget
    s.mytasklist = awful.widget.tasklist {
        screen  = s,
        filter  = awful.widget.tasklist.filter.currenttags,
        buttons = tasklist_buttons
    }

    -- Create the wibox
    s.mywibox = awful.wibar({ position = "top", screen = s })

    -- Add widgets to the wibox
    s.mywibox:setup {
        layout = wibox.layout.align.horizontal,
        { -- Left widgets
            layout = wibox.layout.fixed.horizontal,
            -- mylauncher,
            wibox.container.margin(s.mytaglist, dpi(0), dpi(0)),
            wibox.container.margin(s.mypromptbox, dpi(0), dpi(0)),
        },
        s.mytasklist, -- Middle widget
        { -- Right widgets
            layout = wibox.layout.fixed.horizontal,
            spacing = dpi(10),
            {
              drivewidget,
              left = dpi(10),
              layout = wibox.container.margin,
            },
            memwidget,
            cpuwidget,
            keyboardlayoutwidget,
            systraywidget,
            textclockwidget,
            s.mylayoutbox
        },
    }
end)
-- }}}

-- {{{ Mouse bindings
root.buttons(gears.table.join(
    awful.button({ }, 3, function () mymainmenu:toggle() end),
    awful.button({ }, 4, awful.tag.viewnext),
    awful.button({ }, 5, awful.tag.viewprev)
))
-- }}}

-- {{{ Key bindings
globalkeys = gears.table.join(
    awful.key({ modkey,           }, "s",      hotkeys_popup.show_help,
              {description="show help", group="awesome"}),
    awful.key({ modkey,           }, "Left",   awful.tag.viewprev,
              {description = "view previous", group = "tag"}),
    awful.key({ modkey,           }, "Right",  awful.tag.viewnext,
              {description = "view next", group = "tag"}),
    awful.key({ modkey,           }, "Escape", awful.tag.history.restore,
              {description = "go back", group = "tag"}),

    awful.key({ modkey,           }, "j",
        function ()
            awful.client.focus.bydirection('down')
        end,
        {description = "focus bottom client", group = "client"}
    ),
    awful.key({ modkey,           }, "k",
        function ()
            awful.client.focus.bydirection('up')
        end,
        {description = "focus upper client", group = "client"}
    ),
    awful.key({ modkey,           }, "w", function () mymainmenu:show() end,
              {description = "show main menu", group = "awesome"}),

    -- Layout manipulation
    awful.key({ modkey, "Shift"   }, "j", function () awful.client.swap.bydirection('down')    end,
              {description = "swap with bottom client", group = "client"}),
    awful.key({ modkey, "Shift"   }, "k", function () awful.client.swap.bydirection('up')    end,
              {description = "swap with upper client", group = "client"}),
    awful.key({ modkey, "Control" }, "h", function () awful.screen.focus_bydirection('left') end,
              {description = "focus left screen", group = "screen"}),
    awful.key({ modkey, "Control" }, "l", function () awful.screen.focus_bydirection('right') end,
              {description = "focus right screen", group = "screen"}),
    awful.key({ modkey, "Control" }, "j", function () awful.screen.focus_bydirection('down') end,
              {description = "focus up screen", group = "screen"}),
    awful.key({ modkey, "Control" }, "k", function () awful.screen.focus_bydirection('up') end,
              {description = "focus down screen", group = "screen"}),


    awful.key({ modkey,           }, "u", awful.client.urgent.jumpto,
              {description = "jump to urgent client", group = "client"}),
    awful.key({ modkey,           }, "Tab",
        function ()
            awful.client.focus.history.previous()
            if client.focus then
                client.focus:raise()
            end
        end,
        {description = "go back", group = "client"}),

    awful.key({ "Mod1",           }, "Tab",
        function ()
          awful.client.cycle(true)
          awful.client.focus.byidx(0, awful.client.getmaster())
        end,
        {description = "cycle clients", group = "client"}),

    awful.key({ modkey, "Mod1" }, "h", function () awful.tag.incmwfact(-0.01) end,
              {description = "resize to left", group = "client"}),
    awful.key({ modkey, "Mod1" }, "l", function () awful.tag.incmwfact(0.01) end,
              {description = "resize to right", group = "client"}),
    -- awful.key({ modkey, "Mod1" }, "j", function () awful.client.incmwfact(0.05) end,
    --           {description = "resize to bottom", group = "client"}),
    -- awful.key({ modkey, "Mod1" }, "k", function () awful.client.incmwfact(-0.05) end,
    --           {description = "resize to top", group = "client"}),

    -- Standard program
    awful.key({ modkey,           }, "Return", function () awful.spawn(terminal) end,
              {description = "open a terminal", group = "launcher"}),
    awful.key({ modkey, "Control" }, "r", awesome.restart,
              {description = "reload awesome", group = "awesome"}),
    awful.key({ modkey, "Mod1"   }, "q", awesome.quit,
              {description = "quit awesome", group = "awesome"}),

    awful.key({ modkey,           }, "l",     function () awful.client.focus.bydirection('right')          end,
              {description = "focus right client", group = "layout"}),
    awful.key({ modkey,           }, "h",     function () awful.client.focus.bydirection('left')          end,
              {description = "focus left client", group = "layout"}),
    awful.key({ modkey, "Shift"   }, "h",     function () awful.client.swap.bydirection('left') end,
              {description = "swap with left client", group = "layout"}),
    awful.key({ modkey, "Shift"   }, "l",     function () awful.client.swap.bydirection('right') end,
              {description = "swap with right client", group = "layout"}),
    awful.key({ modkey, "Control" }, "h",     function () awful.tag.incncol( 1, nil, true)    end,
              {description = "increase the number of columns", group = "layout"}),
    awful.key({ modkey, "Control" }, "l",     function () awful.tag.incncol(-1, nil, true)    end,
              {description = "decrease the number of columns", group = "layout"}),
    awful.key({ modkey,           }, "t", function () awful.layout.inc( 1)                end,
              {description = "select next", group = "layout"}),
    awful.key({ modkey, "Shift"   }, "t", function () awful.layout.inc(-1)                end,
              {description = "select previous", group = "layout"}),

    awful.key({ modkey, "Control" }, "n",
              function ()
                  local c = awful.client.restore()
                  -- Focus restored client
                  if c then
                    c:emit_signal(
                        "request::activate", "key.unminimize", {raise = true}
                    )
                  end
              end,
              {description = "restore minimized", group = "client"}),

    -- Keybind
    awful.key({ modkey }, "b", function () awful.spawn('firefox') end,
              { description = "opens web browser", group = "gui app" }),
    awful.key({ modkey, "Control" }, "Return", function () awful.spawn('rofi -show drun') end,
              { description = "opens rofi", group = "gui app" }),
    awful.key({ modkey }, "e", function () awful.spawn('alacritty -e lf') end,
              { description = "opens lf file manager", group = "cli app" }),
    awful.key({ modkey }, "c", function () awful.spawn('alacritty --class calcurse,Calcurse --title Calcurse -e calcurse') end,
              { description = "opens calcurse calendar", group = "cli app" }),
    awful.key({ modkey }, "period", function () awful.spawn('rofi -show emoji -modi emoji') end,
              { description = "opens emoji explorer", group = "gui app" }),
    awful.key({ modkey, "Control" }, "k", function () awful.spawn.with_shell('$HOME/.scripts/toggle-picom.sh') end,
              { description = "toggle compositor", group = "launcher" }),

    -- Screenshot
    awful.key({}, "Print",
      function () awful.spawn.with_shell(
	      "maim | xclip -selection clipboard -t image/png"
        )
      end,
      { description = "take screenshot", group = "launcher" }
    ),
    awful.key({ "Control", "Shift" }, "p",
      function () awful.spawn.with_shell(
        -- "~/.scripts/screenshot.sh"
        "flameshot gui"
        )
      end,
      { description = "take screenshot region", group = "launcher" }
    ),

    -- Media Controls
    awful.key({}, "XF86AudioRaiseVolume", function ()
      awful.spawn.with_shell('amixer -D pulse -q sset -M Master 5%+ && $HOME/.scripts/volume_status_notify.sh') end,
      { description = "Increase volume", group = "media"}),
    awful.key({}, "XF86AudioLowerVolume", function ()
      awful.spawn.with_shell('amixer -D pulse -q sset -M Master 5%- && $HOME/.scripts/volume_status_notify.sh') end,
      { description = "Decrease volume", group = "media"}),
    awful.key({}, "XF86AudioMute", function ()
      awful.spawn.with_shell('amixer -q sset Master toggle && $HOME/.scripts/volume_status_notify.sh') end,
      { description = "Audio Mute", group = "media"}),
    awful.key({}, "XF86AudioPlay", function ()
      awful.spawn.with_shell('playerctl play-pause') end,
      { description = "Audio play-pause", group = "media"}),
    awful.key({}, "XF86AudioNext", function ()
      awful.spawn.with_shell('playerctl next') end,
      { description = "Audio next", group = "media"}),
    awful.key({}, "XF86AudioPrev", function ()
      awful.spawn.with_shell('playerctl previous') end,
      { description = "Audio previous", group = "media"}),
    awful.key({}, "XF86AudioStop", function ()
      awful.spawn.with_shell('playerctl stop') end,
      { description = "Audio stop", group = "media"}),
    awful.key({ modkey, "Shift" }, "m", function ()
      awful.spawn.with_shell('amixer -D pulse -q sset Capture toggle') end,
      { description = "Toggle microphone", group = "media"}),


    -- Prompt
    awful.key({ modkey },            "r",     function () awful.screen.focused().mypromptbox:run() end,
              {description = "run prompt", group = "launcher"}),

    awful.key({ modkey }, "x",
              function ()
                  awful.prompt.run {
                    prompt       = "Run Lua code: ",
                    textbox      = awful.screen.focused().mypromptbox.widget,
                    exe_callback = awful.util.eval,
                    history_path = awful.util.get_cache_dir() .. "/history_eval"
                  }
              end,
              {description = "lua execute prompt", group = "awesome"}),

    awful.key({ modkey }, "p",
      function()
        awful.spawn.with_shell('alacritty --class spotify-tui,SpotifyTui --title SpotifyTui -e spt')
      end,
              {description = "launch SpotifyTui", group = "launcher"})
)

clientkeys = gears.table.join(
    awful.key({ modkey,           }, "f",
        function (c)
            c.fullscreen = not c.fullscreen
            c:raise()
        end,
        {description = "toggle fullscreen", group = "client"}),
    awful.key({ modkey, "Shift"   }, "q",      function (c) c:kill()                         end,
              {description = "close", group = "client"}),
    awful.key({ modkey, "Control" }, "space",  awful.client.floating.toggle                     ,
              {description = "toggle floating", group = "client"}),
    awful.key({ modkey, "Control" }, "Return", function (c) c:swap(awful.client.getmaster()) end,
              {description = "move to master", group = "client"}),
    awful.key({ modkey,           }, "o",      function (c) c:move_to_screen()               end,
              {description = "move to screen", group = "client"}),
    awful.key({ modkey,           }, "t",      function (c) c.ontop = not c.ontop            end,
              {description = "toggle keep on top", group = "client"}),
    awful.key({ modkey,           }, "n",
        function (c)
            -- The client currently has the input focus, so it cannot be
            -- minimized, since minimized clients can't have the focus.
            c.minimized = true
        end ,
        {description = "minimize", group = "client"}),
    awful.key({ modkey,           }, "m",
        function (c)
            c.maximized = not c.maximized
            c:raise()
        end ,
        {description = "(un)maximize", group = "client"}),
    awful.key({ modkey, "Control" }, "m",
        function (c)
            c.maximized_vertical = not c.maximized_vertical
            c:raise()
        end ,
        {description = "(un)maximize vertically", group = "client"}),
    awful.key({ modkey, "Shift"   }, "m",
        function (c)
            c.maximized_horizontal = not c.maximized_horizontal
            c:raise()
        end ,
        {description = "(un)maximize horizontally", group = "client"})
)

-- Bind all key numbers to tags.
-- Be careful: we use keycodes to make it work on any keyboard layout.
-- This should map on the top row of your keyboard, usually 1 to 9.
for i = 1, 10 do
    globalkeys = gears.table.join(globalkeys,
        -- View tag only.
        awful.key({ modkey }, "#" .. i + 9,
                  function ()
                        local screen = awful.screen.focused()
                        local tag = screen.tags[i]
                        if tag then
                           tag:view_only()
                        end
                  end,
                  {description = "view tag #"..i, group = "tag"}),
        -- -- Toggle tag display.
        -- awful.key({ modkey, "Control" }, "#" .. i + 9,
        --           function ()
        --               local screen = awful.screen.focused()
        --               local tag = screen.tags[i]
        --               if tag then
        --                  awful.tag.viewtoggle(tag)
        --               end
        --           end,
        --           {description = "toggle tag #" .. i, group = "tag"}),
        -- Move client to tag.
        awful.key({ modkey, "Control" }, "#" .. i + 9,
                  function ()
                      if client.focus then
                          local tag = client.focus.screen.tags[i]
                          if tag then
                              client.focus:move_to_tag(tag)
                          end
                     end
                  end,
                  {description = "move focused client to tag #"..i, group = "tag"}),
        -- Toggle tag on focused client.
        awful.key({ modkey, "Control", "Shift" }, "#" .. i + 9,
                  function ()
                      if client.focus then
                          local tag = client.focus.screen.tags[i]
                          if tag then
                              client.focus:toggle_tag(tag)
                          end
                      end
                  end,
                  {description = "toggle focused client on tag #" .. i, group = "tag"})
    )
end

clientbuttons = gears.table.join(
    awful.button({ }, 1, function (c)
        c:emit_signal("request::activate", "mouse_click", {raise = true})
    end),
    awful.button({ modkey }, 1, function (c)
        c:emit_signal("request::activate", "mouse_click", {raise = true})
        awful.mouse.client.move(c)
    end),
    awful.button({ modkey }, 3, function (c)
        c:emit_signal("request::activate", "mouse_click", {raise = true})
        awful.mouse.client.resize(c)
    end)
)

-- Set keys
root.keys(globalkeys)
-- }}}

-- {{{ Rules
-- Rules to apply to new clients (through the "manage" signal).
awful.rules.rules = {
    -- All clients will match this rule.
    { rule = { },
      properties = { border_width = beautiful.border_width,
                     border_color = beautiful.border_normal,
                     focus = awful.client.focus.filter,
                     raise = true,
                     maximized = false,
                     keys = clientkeys,
                     buttons = clientbuttons,
                     screen = awful.screen.preferred,
                     placement = awful.placement.no_overlap+awful.placement.no_offscreen
     }
    },

    -- Floating clients.
    { rule_any = {
        instance = {
          "DTA",  -- Firefox addon DownThemAll.
          "copyq",  -- Includes session name in class.
          "pinentry",
        },
        class = {
          "Arandr",
          "Blueman-manager",
          "Gpick",
          "Kruler",
          "MessageWin",  -- kalarm.
          "Nitrogen",
          "Pavucontrol",
          "Steam",
          "Sxiv",
          "Tor Browser", -- Needs a fixed window size to avoid fingerprinting by screen size.
          "Wpa_gui",
          "veromix",
          "xtightvncviewer"},

        -- Note that the name property shown in xprop might be set slightly after creation of the client
        -- and the name shown there might not match defined rules here.
        name = {
          "Event Tester",  -- xev.
          ".*Emulator.*",  -- Android Emulator
        },
        role = {
          "AlarmWindow",  -- Thunderbird's calendar.
          "ConfigManager",  -- Thunderbird's about:config.
          "pop-up",       -- e.g. Google Chrome's (detached) Developer Tools.
        }
      }, properties = { floating = true, placement = awful.placement.centered }},

    -- Add titlebars to normal clients and dialogs
    { rule_any = {type = { "normal", "dialog" }
      }, properties = { titlebars_enabled = false }
    },

    -- Spawn in tags and screen
    { rule = { class = "discord" },
      properties = { screen = 1, tag = TAGS[9] } },
    { rule = { class = "Steam" },
      properties = { screen = 1, tag = TAGS[4] } },
    { rule = { class = "Thunderbird" },
      properties = { screen = 1, tag = TAGS[6] } },
    { rule = { class = "Calcurse" },
      properties = { screen = 1, tag = TAGS[7] } },
    { rule = { class = "TelegramDesktop" },
      properties = { screen = 1, tag = TAGS[8] } },
    { rule = { class = "SpotifyTui" },
      properties = { screen = 1, tag = TAGS[10] } },
}
-- }}}

-- {{{ Signals
-- Signal function to execute when a new client appears.
client.connect_signal("manage", function (c)
    -- Set the windows at the slave,
    -- i.e. put it at the end of others instead of setting it master.
    -- if not awesome.startup then awful.client.setslave(c) end

    if awesome.startup
      and not c.size_hints.user_position
      and not c.size_hints.program_position then
        -- Prevent clients from being unreachable after screen count changes.
        awful.placement.no_offscreen(c)
    end
end)

-- Add a titlebar if titlebars_enabled is set to true in the rules.
client.connect_signal("request::titlebars", function(c)
    -- buttons for the titlebar
    local buttons = gears.table.join(
        awful.button({ }, 1, function()
            c:emit_signal("request::activate", "titlebar", {raise = true})
            awful.mouse.client.move(c)
        end),
        awful.button({ }, 3, function()
            c:emit_signal("request::activate", "titlebar", {raise = true})
            awful.mouse.client.resize(c)
        end)
    )

    awful.titlebar(c) : setup {
        { -- Left
            awful.titlebar.widget.iconwidget(c),
            buttons = buttons,
            layout  = wibox.layout.fixed.horizontal
        },
        { -- Middle
            { -- Title
                align  = "center",
                widget = awful.titlebar.widget.titlewidget(c)
            },
            buttons = buttons,
            layout  = wibox.layout.flex.horizontal
        },
        { -- Right
            awful.titlebar.widget.floatingbutton (c),
            awful.titlebar.widget.maximizedbutton(c),
            awful.titlebar.widget.stickybutton   (c),
            awful.titlebar.widget.ontopbutton    (c),
            awful.titlebar.widget.closebutton    (c),
            layout = wibox.layout.fixed.horizontal()
        },
        layout = wibox.layout.align.horizontal
    }
end)

-- Enable sloppy focus, so that focus follows mouse.
-- client.connect_signal("mouse::enter", function(c)
--     c:emit_signal("request::activate", "mouse_enter", {raise = false})
-- end)

client.connect_signal("focus", function(c) c.border_color = beautiful.border_focus end)
client.connect_signal("unfocus", function(c) c.border_color = beautiful.border_normal end)
-- }}}

-- Gaps
beautiful.useless_gap = 3

-- Autostart
awful.spawn.with_shell('~/.scripts/autostart-default')
