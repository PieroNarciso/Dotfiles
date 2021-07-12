#!/bin/sh

selection=$(hacksaw -f "-i %i -g %g" -c \#458588)
shotgun $selection - | xclip -t 'image/png' -selection clipboard
