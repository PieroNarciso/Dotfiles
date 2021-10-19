#!/bin/sh

if pgrep -x picom > /dev/null; then
    pkill picom &
else
    picom --experimental-backends &
fi
