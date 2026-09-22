#!/usr/bin/env bash

set -u

runtime_dir="${XDG_RUNTIME_DIR:-/tmp}/changteezy-screensaver"
screensaver_class="org.changteezy.screensaver"
mode="${1:-lock}"

if pidof hyprlock >/dev/null 2>&1; then
    exit 0
fi

if pgrep -f "alacritty --class=$screensaver_class" >/dev/null 2>&1; then
    exit 0
fi

mkdir -p "$runtime_dir"
date +%s >"$runtime_dir/started-at"

launch_command="alacritty --class=$screensaver_class --config-file $HOME/.config/hypr/screensaver/alacritty.toml -e $HOME/.config/hypr/scripts/screensaver.sh"

# This setup uses Hyprland's Lua dispatchers; retain a standard-dispatcher
# fallback so the script also survives a future switch back to Hyprlang.
hyprctl dispatch "hl.dsp.exec_cmd([[$launch_command]])" >/dev/null 2>&1 ||
    hyprctl dispatch exec -- bash -lc "$launch_command"

# Idle launches become a secure lock after 30 seconds. Preview has no timer.
if [[ "$mode" == "lock" ]]; then
    (
        sleep 30
        rm -f "$runtime_dir/timer.pid"

        if pgrep -f "alacritty --class=$screensaver_class" >/dev/null 2>&1; then
            loginctl lock-session
        fi
    ) &

    printf '%s\n' "$!" >"$runtime_dir/timer.pid"
fi
