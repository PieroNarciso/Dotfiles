#!/bin/sh
msg_id="991049"
icon_audio_activate="notification-audio-volume-high"
icon_audio_muted="notification-audio-volume-muted"

volume="$(amixer get Master | tail -1 | awk '{print $5}' | sed 's/[^0-9]*//g')"
mute="$(amixer get Master | tail -1 | awk '{print $6}' | sed 's/[^a-z]*//g')"

if [[ $volume == 0 || "$mute" == "off" ]]; then
    # Show the sound muted notification
    dunstify -u low -i $icon_audio_muted -r "$msg_id" -t 2000 "Volume muted"
else
    # Show the sound activate notification
    bar=$(seq -s "─" $(($volume / 5)) | sed 's/[0-9]//g')
    dunstify -u low -i $icon_audio_activate -r "$msg_id" -t 2000 \
	"Vol: ${volume}%  $bar"
fi
