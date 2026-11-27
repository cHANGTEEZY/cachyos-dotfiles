#!/bin/bash
# Open Brave on the workspace you are already using.
# An existing Brave window is brought here instead of sending you to its old workspace.

set -u

current_workspace() {
    hyprctl activeworkspace -j | python3 -c 'import json,sys; print(json.load(sys.stdin)["id"])'
}

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

bring_here() {
    local address="$1"
    local workspace="$2"
    hyprctl dispatch "hl.dsp.window.move({ window = \"address:${address}\", workspace = ${workspace} })" >/dev/null
}

workspace=$(current_workspace)
address=$(brave_address)

if [[ -n "$address" ]]; then
    bring_here "$address" "$workspace"
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
        bring_here "$address" "$workspace"
        exit 0
    fi
    sleep 0.1
done

exit 0
