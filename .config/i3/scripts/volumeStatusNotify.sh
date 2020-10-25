#!/usr/bin/bash
msgId="991049"
iconAudioActivate="notification-audio-volume-high"
iconAudioMuted="notification-audio-volume-muted"

volume="$(amixer get Master | tail -1 | awk '{print $5}' | sed 's/[^0-9]*//g')"
mute="$(amixer get Master | tail -1 | awk '{print $6}' | sed 's/[^a-z]*//g')"

if [[ $volume == 0 || "$mute" == "off" ]]; then
    # Show the sound muted notification
    dunstify -u low -i $iconAudioMuted -r "$msgId" -t 2000 "Volume muted"
else
    bar=$(seq -s "─" $(($volume / 5)) | sed 's/[0-9]//g')
    dunstify -u low -i $iconAudioActivate -r "$msgId" -t 2000 \
	"Volume: ${volume}%     $bar"
fi
