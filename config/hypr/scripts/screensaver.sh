#!/usr/bin/env bash

set -u

runtime_dir="${XDG_RUNTIME_DIR:-/tmp}/changteezy-screensaver"
art_file="$HOME/.config/hypr/screensaver/changteezy.txt"
normalized_art="$runtime_dir/art.txt"
tte_pid=""

# Omarchy's screensaver animates the wordmark with Terminal Text Effects.
# The engine lives in a user venv; ttfx/tte on PATH are accepted too.
resolve_tte() {
    local candidate
    for candidate in \
        "$HOME/.local/share/changteezy/tte/bin/tte" \
        "$HOME/.local/bin/ttfx" \
        "$HOME/.local/bin/tte"
    do
        if [[ -x "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    if command -v ttfx >/dev/null 2>&1; then
        command -v ttfx
        return 0
    fi
    if command -v tte >/dev/null 2>&1; then
        command -v tte
        return 0
    fi
    return 1
}
was_focused=false
started_at=$(date +%s)

mkdir -p "$runtime_dir"
printf '%s\n' "$$" >"$runtime_dir/runner.pid"

# Wait until Alacritty has actually gone fullscreen. TTE samples terminal
# size at start, so a default 80x24 canvas would stay a small centered box.
wait_for_terminal() {
    local rows cols
    for _ in $(seq 1 80); do
        read -r rows cols < <(stty size 2>/dev/null || echo "0 0")
        if (( rows >= 30 && cols >= 80 )); then
            return 0
        fi
        sleep 0.05
    done
}

# Keep the original character grid. Stretching it to the terminal size is
# what made the figure look warped and "not to scale".
normalize_art() {
    python3 - "$art_file" "$normalized_art" <<'PY'
from pathlib import Path
import sys

source, destination = map(Path, sys.argv[1:3])
lines = source.read_text().splitlines()

while lines and not lines[0].strip():
    lines.pop(0)
while lines and not lines[-1].strip():
    lines.pop()

margin = min((len(line) - len(line.lstrip()) for line in lines if line.strip()), default=0)
destination.write_text("\n".join(line[margin:].rstrip() for line in lines) + "\n")
PY
}

screensaver_in_focus() {
    hyprctl activewindow -j 2>/dev/null |
        jq -e '.class == "org.changteezy.screensaver"' >/dev/null 2>&1
}

keep_running() {
    [[ -f "$runtime_dir/persist" ]]
}

show_cursor() {
    hyprctl eval 'hl.config({ cursor = { invisible = false } })' >/dev/null 2>&1 ||
        hyprctl keyword cursor:invisible false >/dev/null 2>&1 ||
        true
}

hide_cursor() {
    hyprctl eval 'hl.config({ cursor = { invisible = true } })' >/dev/null 2>&1 ||
        hyprctl keyword cursor:invisible true >/dev/null 2>&1 ||
        true
}

cleanup() {
    trap - EXIT INT TERM HUP QUIT

    if [[ -n "$tte_pid" ]]; then
        kill "$tte_pid" 2>/dev/null || true
    fi

    if [[ -s "$runtime_dir/timer.pid" ]]; then
        timer_pid=$(<"$runtime_dir/timer.pid")
        kill "$timer_pid" 2>/dev/null || true
    fi

    rm -f "$runtime_dir/runner.pid" "$runtime_dir/timer.pid"
    show_cursor
}

trap cleanup EXIT INT TERM HUP QUIT

printf '\033]11;rgb:00/00/00\007\033[2J\033[H'
hide_cursor
wait_for_terminal

if [[ ! -f "$art_file" ]]; then
    printf 'screensaver: missing %s\n' "$art_file" >&2
    sleep 4
    exit 1
fi
normalize_art

if ! tte=$(resolve_tte); then
    printf '\033[2J\033[H'
    cat "$normalized_art"
    printf '\n\nscreensaver: install ttfx or terminaltexteffects to animate this\n'
    read -rsn1 -t 8 || true
    exit 0
fi

while true; do
    "$tte" -i "$normalized_art" \
        --frame-rate 120 \
        --canvas-width 0 \
        --canvas-height 0 \
        --reuse-canvas \
        --anchor-canvas c \
        --anchor-text c \
        --random-effect \
        --no-eol \
        --no-restore-cursor &
    tte_pid=$!

    while kill -0 "$tte_pid" 2>/dev/null; do
        if keep_running; then
            sleep 0.25
            continue
        fi

        if screensaver_in_focus; then
            was_focused=true
        elif [[ "$was_focused" == true ]] || (( $(date +%s) - started_at > 4 )); then
            exit 0
        fi

        if read -rsn1 -t 0.25; then
            exit 0
        fi
    done

    wait "$tte_pid" 2>/dev/null || true
    tte_pid=""
done
