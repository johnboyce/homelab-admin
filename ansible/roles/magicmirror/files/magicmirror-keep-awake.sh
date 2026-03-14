#!/bin/bash
# Keeps the display awake by wiggling the mouse every 60 seconds.
# Started by the wake script, killed by the sleep script.
# This prevents GNOME's idle timer from blanking the screen without
# disabling any power management settings.

export DISPLAY=:0
export XAUTHORITY=/home/johnb/.Xauthority

while true; do
    xdotool mousemove_relative -- 1 0
    sleep 0.5
    xdotool mousemove_relative -- -1 0
    sleep 60
done
