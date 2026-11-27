#!/bin/bash
# Open Brave. If it is already open, go to that window's workspace.

set -u

brave_address() {
    hyprctl clients -j | python3 -c '
import json, sys
try:
    clients = json.load(sys.stdin)
except Exception:
    raise SystemExit(0)
windows = [c for c in clients if (c.get("class") or "") == "brave-browser"]
if not windows:
    raise SystemExit(0)
windows.sort(key=lambda c: c.get("focusHistoryID") if c.get("focusHistoryID") is not None else 9999)
print(windows[0].get("address") or "")
'
}

focus_address() {
    hyprctl dispatch "hl.dsp.focus({ window = \"address:$1\" })" >/dev/null
}

address=$(brave_address)
if [[ -n "$address" ]]; then
    focus_address "$address"
    exit 0
fi

if command -v uwsm >/dev/null && uwsm check is-active >/dev/null 2>&1; then
    uwsm app -- brave >/dev/null 2>&1 &
else
    brave >/dev/null 2>&1 &
fi

for _ in $(seq 1 40); do
    address=$(brave_address)
    if [[ -n "$address" ]]; then
        focus_address "$address"
        exit 0
    fi
    sleep 0.1
done

exit 0
