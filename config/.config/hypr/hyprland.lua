-- Hyprland config (Lua) — migrated from hyprland.conf
-- Hyprland >= 0.55 uses Lua; hyprlang (.conf) is deprecated.
-- The old hyprland.conf is kept as a backup. If both exist, this .lua wins.
-- To revert: delete/rename this file, Hyprland falls back to hyprland.conf.
-- Wiki: https://wiki.hypr.land/Configuring/Start/

------------------
---- PROGRAMS ----
------------------
local terminal    = "alacritty"
local fileManager = "nemo"
local mainMod     = "SUPER"

------------------
---- MONITORS ----
------------------
hl.monitor({ output = "DP-3",     mode = "2560x1440@180", position = "0x0",    scale = 1 })
hl.monitor({ output = "HDMI-A-1", mode = "1920x1080@120", position = "2560x0", scale = 1 })

----------------------------------------
---- WORKSPACES (hyprsplit — awesome-like)
----------------------------------------
-- Per-monitor independent workspaces. Replaces the old split-monitor-workspaces plugin.
-- Clone lives at ~/.config/hypr/hyprsplit (git, .gitignored).
local hs = require("hyprsplit")
hs.config({
    num_workspaces        = 10,    -- per monitor (was max_workspaces 10/monitor)
    persistent_workspaces = false, -- was enable_persistent_workspaces = 0
})
-- First listed monitor gets workspaces 1-10, second gets 11-20 (matches old monitor_priority).
hs.monitor_priority({ "DP-3", "HDMI-A-1" })

-------------------
---- AUTOSTART ----
-------------------
hl.on("hyprland.start", function()
    hl.exec_cmd("waybar")
    hl.exec_cmd("hyprpaper")
    hl.exec_cmd("hyprlock")
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    hl.exec_cmd("dunst")
    hl.exec_cmd("nm-applet")
    hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    hl.exec_cmd("protonvpn-app --start-minimized")
end)

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------
hl.env("XCURSOR_SIZE", "24")
hl.env("QT_QPA_PLATFORMTHEME", "qt5ct") -- change to qt6ct if you have that
hl.env("BAT_THEME", "gruvbox-dark")
hl.env("GTK_THEME", "Gruvbox-B-MB-Dark-Medium")
hl.env("TDESKTOP_USE_GTK_FILE_DIALOG", "1")

-----------------------
---- LOOK AND FEEL ----
-----------------------
hl.config({
    input = {
        kb_layout    = "us,us",
        kb_variant   = ",altgr-intl",
        kb_model     = "",
        kb_options   = "grp:win_space_toggle,caps:escape",
        kb_rules     = "",
        follow_mouse = 1,
        touchpad = {
            natural_scroll = false,
        },
        accel_profile = "flat",
        sensitivity   = 0, -- -1.0 - 1.0, 0 means no modification.
    },

    general = {
        gaps_in     = 3,
        gaps_out    = 8,
        border_size = 2,
        col = {
            active_border   = { colors = { "rgba(fabd2fee)", "rgba(fe8019ee)" }, angle = 45 }, -- gruvbox yellow->orange
            inactive_border = "rgba(3c3836aa)",
        },
        layout        = "dwindle",
        allow_tearing = false,
    },

    decoration = {
        rounding = 4,
        blur = {
            enabled = true,
            size    = 3,
            passes  = 1,
            vibrancy = 0.1696,
        },
    },

    dwindle = {
        preserve_split = true,
    },

    master = {
        new_status = "slave",
    },

    misc = {
        force_default_wallpaper  = 0,
        disable_hyprland_logo    = true, -- no corner logo
        disable_splash_rendering = true, -- no random quip text over wallpaper
    },

    animations = {
        enabled = true,
    },
})

-----------------
---- ANIMATIONS --
-----------------
-- Lua API verified against shipped /usr/share/hypr/hyprland.lua (0.55.2).
-- Curves: bezier = control points; spring = physical params.
hl.curve("easeOutQuint",   { type = "bezier", points = { { 0.23, 1 },    { 0.32, 1 } } })
hl.curve("easeInOutCubic", { type = "bezier", points = { { 0.65, 0.05 }, { 0.36, 1 } } })
hl.curve("linear",         { type = "bezier", points = { { 0, 0 },       { 1, 1 } } })
hl.curve("almostLinear",   { type = "bezier", points = { { 0.5, 0.5 },   { 0.75, 1 } } })
hl.curve("quick",          { type = "bezier", points = { { 0.15, 0 },    { 0.1, 1 } } })
hl.curve("easy",           { type = "spring", mass = 1, stiffness = 71.2633, dampening = 15.8273644 })

hl.animation({ leaf = "global",        enabled = true, speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true, speed = 4.79, spring = "easy" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 4.1,  spring = "easy",         style = "popin 87%" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 1.49, bezier = "linear",       style = "popin 87%" })
hl.animation({ leaf = "fadeIn",        enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "workspaces",    enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn",  enabled = true, speed = 1.21, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })

-------------
---- BINDS --
-------------
hl.bind(mainMod .. " + Return",           hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + SHIFT + Q",        hl.dsp.window.close())
hl.bind(mainMod .. " + E",                hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + T",                hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + CONTROL + Return", hl.dsp.exec_cmd("rofi -show drun"))
hl.bind(mainMod .. " + period",           hl.dsp.exec_cmd("rofi -show emoji -modi emoji")) -- emoji picker (rofi-emoji); Enter=insert needs wtype, Alt+c=copy
hl.bind(mainMod .. " + B",                hl.dsp.exec_cmd("brave"))
hl.bind(mainMod .. " + X",                hl.dsp.exec_cmd("~/.config/waybar/scripts/power.sh"))
hl.bind(mainMod .. " + P",                hl.dsp.window.pseudo())
hl.bind(mainMod .. " + SHIFT + S",        hl.dsp.exec_cmd("~/.config/hypr/scripts/screenshot.sh"))
hl.bind(mainMod .. " + V",                hl.dsp.exec_cmd("cliphist list | wofi --dmenu | cliphist decode | wl-copy"))

-- Move focus (vim keys)
hl.bind(mainMod .. " + H", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + L", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + K", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + J", hl.dsp.focus({ direction = "down" }))

-- Window / monitor
hl.bind(mainMod .. " + F",           hl.dsp.window.fullscreen({ action = "toggle" }))
hl.bind(mainMod .. " + O",           hl.dsp.window.move({ monitor = "+1" })) -- TODO verify monitor-move syntax
hl.bind(mainMod .. " + CONTROL + L", hl.dsp.focus({ monitor = "r" }))
hl.bind(mainMod .. " + CONTROL + H", hl.dsp.focus({ monitor = "l" }))

-- Multimedia keys
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_SINK@ 5%+"))
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_SINK@ 5%-"))
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_SINK@ toggle"))
hl.bind("XF86AudioNext",        hl.dsp.exec_cmd("playerctl next"))
hl.bind("XF86AudioPrev",        hl.dsp.exec_cmd("playerctl previous"))
hl.bind("XF86AudioPlay",        hl.dsp.exec_cmd("playerctl play-pause"))
hl.bind("XF86AudioStop",        hl.dsp.exec_cmd("playerctl stop"))
hl.bind(mainMod .. " + SHIFT + M", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_SOURCE@ toggle"))

-- Workspaces (hyprsplit): SUPER+N switch on current monitor, SUPER+CTRL+N move window there
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(mainMod .. " + " .. key,           hs.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + CONTROL + " .. key, hs.dsp.window.move({ workspace = i }))
end

-- Move/resize windows with mainMod + LMB/RMB drag
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

--------------------
---- WINDOW RULES --
--------------------
-- GTK file picker (xdg-desktop-portal-gtk) under Hyprland: GTK's client-side
-- decoration shadow is a transparent surface margin that the compositor blurs,
-- giving a fuzzy halo/border around the dialog. Kill blur + shadow on it.
hl.window_rule({
    name      = "filechooser-no-blur-halo",
    match     = { class = "(?i)xdg-desktop-portal-gtk" },
    no_blur   = true,
    no_shadow = true,
})
