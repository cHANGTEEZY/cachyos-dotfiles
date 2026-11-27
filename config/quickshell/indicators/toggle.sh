#!/bin/bash
# Flip one indicator: record, awake, dnd, or night.

export PATH="$HOME/.local/bin:$PATH"
state="${XDG_STATE_HOME:-$HOME/.local/state}/changteezy/indicators"
mkdir -p "$state"

notify() {
    notify-send -a "Indicators" -u low "$1" "${2:-}" >/dev/null 2>&1 || true
}

alive() {
    local file="$1"
    [[ -f "$file" ]] || return 1
    local pid
    pid=$(<"$file")
    [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null
}

stop_record() {
    local pid path
    pid=$(<"$state/record.pid")
    path=$(<"$state/record.path" 2>/dev/null || true)
    kill -INT "$pid" 2>/dev/null || true
    local _i
    for _i in $(seq 1 40); do
        kill -0 "$pid" 2>/dev/null || break
        sleep 0.1
    done
    if kill -0 "$pid" 2>/dev/null; then
        kill "$pid" 2>/dev/null || true
    fi
    rm -f "$state/record.pid" "$state/record.start"
    notify "Recording saved" "$path"
}

case "${1:-}" in
    dnd)
        dunstctl set-paused toggle >/dev/null
        ;;
    night)
        "$HOME/.config/waybar/scripts/toggle-gammastep"
        ;;
    awake)
        if [[ -f "$state/caffeine" ]] && alive "$state/caffeine.pid"; then
            kill "$(<"$state/caffeine.pid")" 2>/dev/null || true
            rm -f "$state/caffeine" "$state/caffeine.pid"
            notify "Stay awake" "Off"
        else
            rm -f "$state/caffeine" "$state/caffeine.pid"
            systemd-inhibit --what=idle:sleep --who="Stay awake" --why="Caffeine" --mode=block sleep infinity &
            echo $! >"$state/caffeine.pid"
            touch "$state/caffeine"
            "$HOME/.config/hypr/scripts/stop-screensaver.sh" force >/dev/null 2>&1 || true
            notify "Stay awake" "The screen will not lock or sleep"
        fi
        ;;
    record)
        if alive "$state/record.pid"; then
            stop_record
            exit 0
        fi
        recorder=$(command -v wf-recorder || true)
        if [[ -z "$recorder" ]]; then
            notify "Record" "wf-recorder is not installed"
            exit 1
        fi
        geom=$(slurp 2>/dev/null || true)
        if [[ -z "$geom" ]]; then
            exit 0
        fi
        file="$HOME/Videos/recording-$(date +%Y%m%d-%H%M%S).mp4"
        audio=$(pactl list short sources 2>/dev/null | awk 'tolower($0) ~ /monitor/ {print $2; exit}')
        if [[ -n "$audio" ]]; then
            "$recorder" --audio="$audio" -g "$geom" -f "$file" >"$state/record.log" 2>&1 &
        else
            "$recorder" -g "$geom" -f "$file" >"$state/record.log" 2>&1 &
        fi
        echo $! >"$state/record.pid"
        date +%s >"$state/record.start"
        echo "$file" >"$state/record.path"
        sleep 0.4
        if ! alive "$state/record.pid"; then
            reason=$(tail -n 1 "$state/record.log" 2>/dev/null || true)
            rm -f "$state/record.pid" "$state/record.start"
            notify "Recording failed" "${reason:-Could not start wf-recorder}"
            exit 1
        fi
        notify "Recording" "Click Record again to stop"
        ;;
    *)
        echo "usage: toggle.sh record|awake|dnd|night" >&2
        exit 1
        ;;
esac
