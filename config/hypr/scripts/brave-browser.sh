#!/bin/bash
# Focus Brave if a window is already open. Otherwise start one.

set -euo pipefail

brave_open() {
    hyprctl clients -j 2>/dev/null | python3 -c '
import json, sys
try:
    clients = json.load(sys.stdin)
except Exception:
    raise SystemExit(1)
for client in clients:
    if (client.get("class") or "") == "brave-browser":
        raise SystemExit(0)
raise SystemExit(1)
'
}

if brave_open; then
    hyprctl dispatch focuswindow "class:^(brave-browser)$" >/dev/null
    exit 0
fi

if command -v uwsm >/dev/null && uwsm check is-active >/dev/null 2>&1; then
    exec uwsm app -- brave
fi

exec brave
