#!/bin/bash
# Compact vertical power menu: right edge, vertically centered.
pgrep -x wlogout >/dev/null && exit 0

BTN=52
GAP=10
RIGHT=24
COUNT=3

geom=$(hyprctl monitors -j 2>/dev/null | python3 -c '
import json, sys
try:
    mons = json.load(sys.stdin)
except Exception:
    sys.exit(1)
m = next((x for x in mons if x.get("focused")), mons[0] if mons else None)
if not m:
    sys.exit(1)
scale = float(m.get("scale") or 1) or 1
width = int(round(int(m["width"]) / scale))
height = int(round(int(m["height"]) / scale))
print(width, height)
' 2>/dev/null) || geom="2560 1440"

read -r WIDTH HEIGHT <<<"$geom"

col_h=$((COUNT * BTN + (COUNT - 1) * GAP))
left=$((WIDTH - RIGHT - BTN))
top=$(( (HEIGHT - col_h) / 2 ))
bottom=$((HEIGHT - top - col_h))

left=$((left < 0 ? 0 : left))
top=$((top < 0 ? 0 : top))
bottom=$((bottom < 0 ? 0 : bottom))

exec wlogout -b 1 -c 0 -r "$GAP" -L "$left" -R "$RIGHT" -T "$top" -B "$bottom"
