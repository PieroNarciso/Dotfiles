#!/bin/sh
# Waybar power menu — rofi (reuses gruvbox-dark-soft theme, no wlogout dependency).

theme="$HOME/.config/rofi/themes/gruvbox-dark-soft.rasi"

chosen=$(printf '%s\n' \
    " Lock" \
    " Logout" \
    " Suspend" \
    " Reboot" \
    " Shutdown" \
    | rofi -dmenu -i -p "Power" -theme "$theme")

case "$chosen" in
    *Lock)     hyprlock ;;
    *Logout)   hyprctl dispatch 'hl.dsp.exit()' ;;
    *Suspend)  systemctl suspend ;;
    *Reboot)   systemctl reboot ;;
    *Shutdown) systemctl poweroff ;;
esac
