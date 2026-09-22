#!/bin/bash
# Open one Zen window. If Zen is already running, just focus it.
# A single process still restores every window in sessionstore, so Super+W
# must not spawn a second copy when one is already up.

set -euo pipefail

ZEN_BIN="/opt/zen-browser-bin/zen-bin"
ZEN_CLASS="^(zen)$"

zen_windows() {
    hyprctl clients -j 2>/dev/null | python3 -c '
import json, sys
try:
    clients = json.load(sys.stdin)
except Exception:
    sys.exit(0)
for c in clients:
    cls = (c.get("class") or "")
    if cls == "zen" or cls.startswith("zen-"):
        print(c.get("address", ""), c.get("title", ""), sep="\t")
'
}

focus_zen() {
    hyprctl dispatch focuswindow "class:${ZEN_CLASS}" >/dev/null
}

if pgrep -x zen-bin >/dev/null; then
    focus_zen
    exit 0
fi

# Drop a stale remote lock so a dead previous run cannot be treated as live.
profile=$(find "$HOME/.config/zen" -maxdepth 1 -type d -name '*Default*' 2>/dev/null | head -n1)
if [[ -n "$profile" && -L "$profile/lock" ]] && ! pgrep -x zen-bin >/dev/null; then
    rm -f "$profile/lock"
fi

if command -v uwsm >/dev/null && uwsm check is-active >/dev/null 2>&1; then
    uwsm app -- "$ZEN_BIN" >/dev/null 2>&1 &
else
    "$ZEN_BIN" >/dev/null 2>&1 &
fi

# Wait for the first window, then close a duplicate Wayland extra if it appears.
for _ in $(seq 1 40); do
    if [[ -n "$(zen_windows)" ]]; then
        break
    fi
    sleep 0.1
done
sleep 0.6

python3 - <<'PY'
import json, subprocess

try:
    clients = json.loads(subprocess.check_output(["hyprctl", "clients", "-j"], text=True))
except Exception:
    raise SystemExit(0)

zens = [
    c for c in clients
    if (c.get("class") or "") == "zen" or str(c.get("class") or "").startswith("zen-")
]
if len(zens) <= 1:
    raise SystemExit(0)

def score(c):
    title = (c.get("title") or "").strip().lower()
    # Prefer a restored/content window over the blank extra Zen often maps.
    if title in ("", "zen browser", "new tab", "about:blank"):
        return 0
    return 1

zens.sort(key=score)
# Close every window except the best-scoring one.
keep = zens[-1]["address"]
for c in zens:
    if c["address"] == keep:
        continue
    subprocess.run(
        ["hyprctl", "dispatch", "closewindow", f"address:{c['address']}"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
PY

focus_zen
exit 0
