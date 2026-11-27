#!/usr/bin/env python3
"""Print the local timezone and current UTC offsets for the zones on argv."""

import json
import os
import sys
from datetime import datetime
from zoneinfo import ZoneInfo


def local_zone() -> str:
    path = os.path.realpath("/etc/localtime")
    mark = "/zoneinfo/"
    index = path.find(mark)
    if index >= 0:
        return path[index + len(mark) :]
    return "UTC"


def main() -> None:
    local = local_zone()
    now = datetime.now(ZoneInfo("UTC"))
    offsets = {}
    for zone in [local, *sys.argv[1:]]:
        if zone in offsets:
            continue
        try:
            there = now.astimezone(ZoneInfo(zone))
            offset = there.utcoffset()
        except Exception:
            continue
        if offset is None:
            continue
        offsets[zone] = int(offset.total_seconds() // 60)
    json.dump({"local": local, "offsets": offsets}, sys.stdout)
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
