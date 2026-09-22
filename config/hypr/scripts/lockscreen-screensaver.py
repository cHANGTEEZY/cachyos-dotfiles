#!/usr/bin/env python3
"""Render a TTE-inspired ASCII animation frame as pango markup for hyprlock."""

from __future__ import annotations

import math
import random
import time
from pathlib import Path

ART_FILE = Path.home() / ".config/hypr/screensaver/changteezy.txt"
SCRAMBLE = list(".:-=+*#%@01")
EFFECTS = ("scan", "decrypt", "rain", "ripple", "embers")
EFFECT_SECONDS = 7.0
HOLD_SECONDS = 1.6
CYCLE = EFFECT_SECONDS + HOLD_SECONDS

PALETTE = {
    "hot": "#ffffff",
    "bright": "#d8d8d8",
    "mid": "#8f8f8f",
    "dim": "#4a4a4a",
    "ghost": "#2a2a2a",
}


def load_art() -> list[str]:
    lines = ART_FILE.read_text().splitlines()
    while lines and not lines[0].strip():
        lines.pop(0)
    while lines and not lines[-1].strip():
        lines.pop()

    margin = min((len(line) - len(line.lstrip()) for line in lines if line.strip()), default=0)
    trimmed = [line[margin:].rstrip() for line in lines]
    width = max((len(line) for line in trimmed), default=0)
    return [line.ljust(width) for line in trimmed]


ART = load_art()
HEIGHT = len(ART)
WIDTH = len(ART[0]) if ART else 0
CENTER_X = (WIDTH - 1) / 2
CENTER_Y = (HEIGHT - 1) / 2


def clamp(value: float, lo: float = 0.0, hi: float = 1.0) -> float:
    return lo if value < lo else hi if value > hi else value


def mix(distance: float) -> str:
    if distance < 0.08:
        return PALETTE["hot"]
    if distance < 0.22:
        return PALETTE["bright"]
    if distance < 0.45:
        return PALETTE["mid"]
    if distance < 0.75:
        return PALETTE["dim"]
    return PALETTE["ghost"]


def scramble_char(x: int, y: int, frame: int) -> str:
    return SCRAMBLE[(x * 13 + y * 29 + frame * 7) % len(SCRAMBLE)]


def color_for(effect: str, progress: float, holding: bool, x: int, y: int, frame: int) -> str:
    if holding:
        return PALETTE["mid"] if (x + y + frame) % 17 else PALETTE["bright"]

    if effect == "scan":
        beam = (progress * (WIDTH + 12)) - 6
        return mix(abs(x - beam) / 7.0)

    if effect == "decrypt":
        wave = progress * (WIDTH + HEIGHT)
        revealed = (x + y * 0.35) < wave
        return PALETTE["hot"] if revealed and abs((x + y * 0.35) - wave) < 2.2 else PALETTE["mid" if revealed else "ghost"]

    if effect == "rain":
        column_shift = (y / max(HEIGHT - 1, 1)) - ((progress * 1.8 + (x * 0.17) % 1.0) % 1.2)
        return mix(abs(column_shift) * 2.4)

    if effect == "ripple":
        radius = math.hypot(x - CENTER_X, y - CENTER_Y)
        max_radius = math.hypot(CENTER_X, CENTER_Y) + 2
        ring = progress * (max_radius + 6)
        return mix(abs(radius - ring) / 5.5)

    spark = random.Random((frame * 7919) ^ (x * 104729) ^ (y * 2243)).random()
    flicker = 0.18 if spark > 0.93 else 0.0
    breathe = 0.55 + 0.45 * math.sin((x + y) * 0.35 + progress * math.tau)
    return mix(1.0 - (breathe * 0.55 + flicker))


def glyph_for(effect: str, progress: float, holding: bool, x: int, y: int, source: str, frame: int) -> str:
    if holding or effect != "decrypt":
        return source

    wave = progress * (WIDTH + HEIGHT)
    if (x + y * 0.35) < wave - 1.5:
        return source
    return scramble_char(x, y, frame)


def pango_escape(text: str) -> str:
    return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def render_frame() -> str:
    now = time.time()
    cycle_index = int(now // CYCLE)
    local = now % CYCLE
    holding = local >= EFFECT_SECONDS
    progress = 1.0 if holding else local / EFFECT_SECONDS
    effect = EFFECTS[cycle_index % len(EFFECTS)]
    frame = int(now * 12)

    lines: list[str] = []
    for y, raw in enumerate(ART):
        parts: list[str] = []
        run_color = ""
        run_text: list[str] = []

        def flush() -> None:
            nonlocal run_color, run_text
            if not run_text:
                return
            if run_color:
                parts.append(f'<span foreground="{run_color}">{pango_escape("".join(run_text))}</span>')
            else:
                parts.append(pango_escape("".join(run_text)))
            run_text = []
            run_color = ""

        for x, source in enumerate(raw):
            if source == " ":
                flush()
                parts.append(" ")
                continue

            color = color_for(effect, progress, holding, x, y, frame)
            glyph = glyph_for(effect, progress, holding, x, y, source, frame)
            if run_text and color != run_color:
                flush()
            run_color = color
            run_text.append(glyph)

        flush()
        lines.append("".join(parts))

    body = "<br/>".join(lines)
    return f'<span allow_breaks="true">{body}</span>'


if __name__ == "__main__":
    print(render_frame(), flush=True)
