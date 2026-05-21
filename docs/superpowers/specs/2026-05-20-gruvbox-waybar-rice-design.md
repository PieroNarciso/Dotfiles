# Gruvbox Floating-Islands Rice — Hyprland + Waybar

Date: 2026-05-20
Status: approved (design)

## Goal

Restyle the near-default Hyprland + Waybar setup into a cohesive **Gruvbox** rice with a
**floating-islands** Waybar. Emphasis on Waybar. Reuse existing tooling; add no heavy deps.

## Context (current state)

- Hyprland config is **Lua** (`hyprland.lua`), >= 0.55. `hyprland.conf` kept as backup. Animations currently OFF.
- Per-monitor workspaces via **hyprsplit** Lua lib (monitors `DP-3` 2560x1440@180, `HDMI-A-1` 1920x1080@120; workspaces 1-10 / 11-20).
- Waybar uses the stock example `config` + `style.css` (classic colorful solid blocks).
- Existing theme leanings: rofi `gruvbox-dark-soft`, `BAT_THEME=gruvbox-dark`.
- Installed: `playerctl`, `waybar`, `rofi`, **FiraCode Nerd Font**. NOT installed: `wlogout`.
- Dotfiles are a symlink layout: editing the repo = editing live config.

## Decisions

| Topic | Choice |
|-------|--------|
| Palette | Gruvbox (dark) |
| Waybar style | Floating islands — transparent bar, rounded `#3c3836` blobs, gap from edges |
| Position | Top, per monitor |
| Extra modules | Now-playing media (playerctl), Power menu |
| Power menu | rofi script (no new dep), reuse gruvbox rofi theme. `wlogout` explicitly rejected to avoid install. |
| Animations | Enable smooth (riced bezier + window/workspace/fade) |
| Font | FiraCode Nerd Font |

## Gruvbox palette (reference)

```
bg0 #282828  bg1 #3c3836  bg2 #504945  gray #a89984  fg #ebdbb2
yellow #fabd2f  orange #fe8019  green #b8bb26  aqua #8ec07c  blue #83a598  purple #d3869b  red #fb4934
```

## Waybar layout

- `modules-left`:   `["hyprland/workspaces"]`
- `modules-center`: `["hyprland/window"]`
- `modules-right`:  `["custom/media", "pulseaudio", "network", "cpu", "memory", "temperature", "clock", "tray", "custom/power"]`

Visual grouping into islands via CSS (transparent window, per-module/group rounded bg, margins between logical groups). Workspaces numbered; active = yellow. Drop unused desktop modules (battery, backlight, keyboard-state, language, mode, mpd) unless trivially kept.

### New/changed modules
- `custom/media`: `playerctl metadata --format` script, click = play-pause, scroll = prev/next. Truncate length.
- `custom/power`: opens `~/.config/waybar/scripts/power.sh` → rofi menu (lock / logout / reboot / shutdown / suspend). Lock uses `hyprlock`.

## style.css (islands)

- `window#waybar` transparent.
- Islands: bg `#3c3836`, `border-radius` ~10px, padding, `margin` top+sides to float off edges + gaps between groups.
- Text `#ebdbb2`; accents per module (cpu green, mem aqua, net blue, temp orange, media aqua, clock yellow, power red).
- Active workspace `#fabd2f` on `#282828`; inactive gray; hover subtle.
- Font: `FiraCode Nerd Font` ~13px.

## Hyprland (hyprland.lua)

- Borders: active = gruvbox gradient yellow→orange (`rgba(fabd2fee)` → `rgba(fe8019ee)`, angle 45); inactive `rgba(595959aa)`. Keep rounding 4, blur on.
- Animations: enable. Standard riced set — beziers (e.g. easeOutExpo-like) + animations for `windows`, `workspaces`, `fade`, `border`.

> RISK: Hyprland >= 0.55 Lua animation/bezier API differs from hyprlang. Verify exact `hl.config({ animations = {...} })` / bezier syntax against https://wiki.hypr.land/Configuring/ BEFORE writing. Do not trust training-data hyprlang syntax.

## Out of scope

Weather, updates count, wlogout, new wallpaper, hyprlock restyle, multi-palette theming.

## Success criteria

- Waybar shows floating gruvbox islands on both monitors, top, per-monitor workspaces correct.
- Media module reflects playerctl; power module opens rofi menu and actions work.
- Hyprland animations smooth; gruvbox borders; no config errors on reload.
- No new packages installed.
