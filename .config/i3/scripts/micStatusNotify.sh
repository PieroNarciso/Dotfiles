#!/usr/bin/bash
msgId="991050"
iconActivate="notification-microphone-sensitivity-high"
iconMuted="notification-microphone-sensitivity-muted"

status="$(amixer get Capture | tail -1 | awk '{print $6}' | sed 's/[^a-z]*//g')"
echo $status

if [[ "$status" == "on" ]]; then
    # Notification for mic activated
    dunstify -u low -i $iconActivate -r "$msgId" -t 2000 "Mic active"
else
    # Notification for mic muted
    dunstify -u low -i $iconMuted -r "$msgId" -t 2000 "Mic muted"
fi
