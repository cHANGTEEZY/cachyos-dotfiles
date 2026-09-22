#!/bin/bash
# Toggle the hyprquickpaper wallpaper picker.
# Do not inline this pgrep in a Hyprland bind: pgrep -f would match the
# bind's own sh -c command line and never start Quickshell.

if pgrep -u "$USER" -f '^quickshell .*-c hyprquickpaper' >/dev/null; then
    pkill -u "$USER" -f '^quickshell .*-c hyprquickpaper'
    exit 0
fi

exec quickshell -n -c hyprquickpaper
