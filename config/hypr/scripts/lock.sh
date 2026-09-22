#!/usr/bin/env bash

set -u

if pidof hyprlock >/dev/null 2>&1; then
    exit 0
fi

current_wallpaper=$(
    awww query 2>/dev/null |
        sed -n 's/.*currently displaying: image: //p' |
        head -n1
)

if [[ -n "$current_wallpaper" && -f "$current_wallpaper" ]]; then
    ln -sfn "$current_wallpaper" "$HOME/.config/hypr/lock-wallpaper"
    sed -i "s|^    path = .*|    path = $current_wallpaper|" \
        "$HOME/.config/hypr/hyprlock.conf"
fi

# Static lock: stop the TTE screensaver once hyprlock is covering the screen
# so the desktop never flashes through.
(
    for _ in $(seq 1 50); do
        pidof hyprlock >/dev/null 2>&1 && break
        sleep 0.05
    done
    "$HOME/.config/hypr/scripts/stop-screensaver.sh" force
) &

hyprlock
wait
