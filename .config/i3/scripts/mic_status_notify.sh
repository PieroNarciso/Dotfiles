#!/usr/bin/bash
msg_id="991050"
icon_activate="notification-microphone-sensitivity-high"
icon_muted="notification-microphone-sensitivity-muted"

status="$(amixer get Capture | tail -1 | awk '{print $6}' | sed 's/[^a-z]*//g')"
echo $status

if [[ "$status" == "on" ]]; then
    # Notification for mic activated
    dunstify -u low -i $icon_activate -r "$msg_id" -t 2000 "Mic active"
else
    # Notification for mic muted
    dunstify -u low -i $icon_muted -r "$msg_id" -t 2000 "Mic muted"
fi
