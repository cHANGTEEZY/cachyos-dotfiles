#!/usr/bin/env bash

runtime_dir="${XDG_RUNTIME_DIR:-/tmp}/changteezy-screensaver"
screensaver_class="org.changteezy.screensaver"
force="${1:-}"

# Mapping and focusing the terminal can briefly look like user activity to
# idle daemons. Ignore that synthetic wake-up during a short launch grace.
if [[ "$force" != "force" ]] && pidof hyprlock >/dev/null 2>&1; then
    exit 0
fi

if [[ "$force" != "force" && -s "$runtime_dir/started-at" ]]; then
    started_at=$(<"$runtime_dir/started-at")
    if (( $(date +%s) - started_at < 2 )); then
        exit 0
    fi
fi

if [[ -s "$runtime_dir/timer.pid" ]]; then
    timer_pid=$(<"$runtime_dir/timer.pid")
    kill "$timer_pid" 2>/dev/null || true
fi

if [[ -s "$runtime_dir/runner.pid" ]]; then
    runner_pid=$(<"$runtime_dir/runner.pid")
    kill "$runner_pid" 2>/dev/null || true
fi

pkill -x tte 2>/dev/null || true
pkill -f "alacritty --class=$screensaver_class" 2>/dev/null || true

hyprctl eval 'hl.config({ cursor = { invisible = false } })' >/dev/null 2>&1 ||
    hyprctl keyword cursor:invisible false >/dev/null 2>&1 ||
    true

rm -f \
    "$runtime_dir/runner.pid" \
    "$runtime_dir/timer.pid" \
    "$runtime_dir/started-at" \
    "$runtime_dir/art.txt" \
    "$runtime_dir/persist"
