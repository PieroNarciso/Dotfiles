#!/bin/sh
msg_id="8855754"

if pgrep -x picom > /dev/null; then
    pkill picom &
    dunstify -u low -r "$msg_id" -t 2000 "Compositor Disabled"
else
    picom --experimental-backends &
    dunstify -u low -r "$msg_id" -t 2000 "Compositor Enabled"
fi
