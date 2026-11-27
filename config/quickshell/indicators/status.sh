#!/bin/bash
# Print the indicator modes as one JSON object.

state="${XDG_STATE_HOME:-$HOME/.local/state}/changteezy/indicators"
mkdir -p "$state"

alive() {
    local file="$1"
    [[ -f "$file" ]] || return 1
    local pid
    pid=$(<"$file")
    [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null
}

dnd=false
if [[ "$(dunstctl is-paused 2>/dev/null | tr -d '[:space:]')" == "true" ]]; then
    dnd=true
fi

night=false
if pgrep -x gammastep >/dev/null; then
    night=true
fi

awake=false
if [[ -f "$state/caffeine" ]]; then
    if alive "$state/caffeine.pid"; then
        awake=true
    else
        rm -f "$state/caffeine" "$state/caffeine.pid"
    fi
fi

record=false
elapsed=0
if alive "$state/record.pid"; then
    record=true
    if [[ -f "$state/record.start" ]]; then
        start=$(<"$state/record.start")
        now=$(date +%s)
        elapsed=$((now - start))
        if (( elapsed < 0 )); then
            elapsed=0
        fi
    fi
else
    rm -f "$state/record.pid" "$state/record.start"
fi

printf '{"dnd":%s,"night":%s,"awake":%s,"record":%s,"elapsed":%s}\n' \
    "$dnd" "$night" "$awake" "$record" "$elapsed"
