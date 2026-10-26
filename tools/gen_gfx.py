#!/usr/bin/env python3
"""Generate Juggernaut's graphics tables.

    python3 tools/gen_gfx.py

Writes data/gfx.s:
    dir_dx / dir_dy   64 signed bytes, 127*sin and -127*cos
    back_dx / back_dy 64 signed words, the trailer hitch offset
    lorry_sprites     8 orientations x 32 bytes (2 bytes wide, 14 lines)
    icon_sprites      6 x 54 bytes (3 bytes wide, 18 lines)
    wheel_sprite      30 x 30 wheel, 5 bytes wide, 30 lines
"""
from __future__ import annotations

import math
import os

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, ".."))
DATA = os.path.join(ROOT, "data")

SPR_W, SPR_H = 2, 14          # lorry sprite, in screen bytes / lines
ICON_W, ICON_H = 3, 18
WHEEL_W, WHEEL_H = 5, 30


def pack(rows, width_bytes):
    """rows is a list of lists of 6 px bitmasks (bit 5 = leftmost)."""
    out = []
    for r in rows:
        assert len(r) == width_bytes
        out.extend(0x40 | (v & 0x3F) for v in r)
    return out


def blank_rows(w, h):
    return [[0] * w for _ in range(h)]


def emit_bytes(lines, values, per=16):
    for i in range(0, len(values), per):
        lines.append("        .byte " + ",".join("$%02X" % (v & 0xFF)
                                                 for v in values[i:i + per]))


def lorry_orientation(heading_deg):
    """Draw the lorry pointing at heading_deg into a 12 x 14 pixel grid."""
    ang = math.radians(heading_deg)
    ca, sa = math.cos(ang), math.sin(ang)

    def inside(px, py):
        # rotate the sample point into lorry space (lorry points north)
        lx = px * ca + py * sa
        ly = -px * sa + py * ca
        # the trailer body: an outline, so the road shows through the middle
        if -2.4 <= lx <= 2.4 and -6.5 <= ly <= 6.5:
            if abs(lx) > 1.4 or ly < -5.6 or ly > 5.6:
                return True
        # the cab, solid and a little wider, at the front
        if -2.9 <= lx <= 2.9 and -6.9 <= ly <= -2.6:
            return True
        return False

    grid = blank_rows(SPR_W, SPR_H)
    for by in range(SPR_H):
        for bx in range(SPR_W):
            v = 0
            for i in range(6):
                px = bx * 6 + i - 6 + 0.5      # sprite centre at x = 5.5
                py = by - 7 + 0.5
                if inside(px, py):
                    v |= 0x20 >> i
            grid[by][bx] = v
    return pack(grid, SPR_W)


def trailer_orientation(heading_deg):
    ang = math.radians(heading_deg)
    ca, sa = math.cos(ang), math.sin(ang)

    def inside(px, py):
        lx = px * ca + py * sa
        ly = -px * sa + py * ca
        if not (-2.4 <= lx <= 2.4 and -6.2 <= ly <= 6.2):
            return False
        return abs(lx) > 1.4 or ly < -5.4 or ly > 5.4

    grid = blank_rows(SPR_W, SPR_H)
    for by in range(SPR_H):
        for bx in range(SPR_W):
            v = 0
            for i in range(6):
                px = bx * 6 + i - 6 + 0.5
                py = by - 7 + 0.5
                if inside(px, py):
                    v |= 0x20 >> i
            grid[by][bx] = v
    return pack(grid, SPR_W)


def icon(kind):
    """18 x 18 pixel icon, packed as three bytes a line."""
    grid = [[0] * ICON_W for _ in range(ICON_H)]

    def setb(x, y):
        if 0 <= x < ICON_W * 6 and 0 <= y < ICON_H:
            grid[y][x // 6] |= 0x20 >> (x % 6)

    def rect(x0, y0, x1, y1):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                setb(x, y)

    def frame(x0, y0, x1, y1):
        for x in range(x0, x1 + 1):
            setb(x, y0)
            setb(x, y1)
        for y in range(y0, y1 + 1):
            setb(x0, y)
            setb(x1, y)

    if kind == "start":
        # ignition key
        cx, cy, r = 5, 6, 4
        for y in range(18):
            for x in range(18):
                d = (x - cx) ** 2 + (y - cy) ** 2
                if r * r - r <= d <= r * r + r:
                    setb(x, y)
        rect(9, 5, 14, 6)
        setb(13, 7)
        setb(13, 8)
        rect(12, 9, 13, 11)
    elif kind == "phone":
        # handset on a cradle
        rect(2, 2, 6, 4)
        rect(2, 4, 3, 8)
        rect(11, 2, 15, 4)
        rect(14, 4, 15, 8)
        rect(3, 8, 14, 9)
        rect(4, 10, 13, 13)
        frame(3, 14, 14, 16)
    elif kind == "load":
        # fuel pump
        frame(3, 2, 11, 16)
        rect(5, 4, 9, 7)
        rect(3, 10, 11, 11)
        rect(12, 5, 13, 6)
        rect(13, 6, 14, 12)
        rect(12, 12, 14, 13)
        setb(2, 17)
        setb(12, 17)
    elif kind == "unload":
        # pallet with a down arrow
        rect(2, 12, 15, 12)
        rect(2, 14, 15, 14)
        rect(8, 2, 9, 8)
        for i in range(4):
            setb(6 + i, 7 + i)
            setb(11 - i, 7 + i)
    elif kind == "pause":
        rect(4, 3, 6, 14)
        rect(11, 3, 13, 14)
    else:                                   # resign
        frame(2, 2, 14, 16)
        rect(6, 7, 12, 10)
        for i in range(4):
            setb(5 + i, 5 + i)
            setb(5 + i, 12 - i)
    return pack(grid, ICON_W)


def wheel():
    """Steering wheel: a ring with three spokes, 30 x 30."""
    grid = blank_rows(WHEEL_W, WHEEL_H)
    c = 14.5
    for y in range(WHEEL_H):
        for x in range(WHEEL_W * 6):
            dx, dy = x - c, y - c
            d = math.hypot(dx, dy)
            on = 12.0 <= d <= 14.2
            # spokes
            if on or (abs(dy) < 1.2 and abs(dx) < 12) or \
               (dy > 0 and abs(dx + dy * 0.55) < 1.2 and d < 12) or \
               (dy > 0 and abs(dx - dy * 0.55) < 1.2 and d < 12):
                grid[y][x // 6] |= 0x20 >> (x % 6)
    return pack(grid, WHEEL_W)


def main() -> int:
    lines = ["; generated by tools/gen_gfx.py - do not edit",
             "        .export dir_dx, dir_dy, back_dx, back_dy",
             "        .export lorry_sprites, icon_sprites, wheel_sprite",
             "        .segment \"RODATA\""]

    dx = [int(round(127 * math.sin(2 * math.pi * i / 64))) for i in range(64)]
    dy = [int(round(-127 * math.cos(2 * math.pi * i / 64))) for i in range(64)]
    lines.append("dir_dx:")
    emit_bytes(lines, [v & 0xFF for v in dx])
    lines.append("dir_dy:")
    emit_bytes(lines, [v & 0xFF for v in dy])

    # trailer hitch offset: backwards is (-sin, +cos) * 160, as signed words
    bx = [int(round(-160 * math.sin(2 * math.pi * i / 64))) for i in range(64)]
    by = [int(round(160 * math.cos(2 * math.pi * i / 64))) for i in range(64)]
    lines.append("back_dx:")
    emit_bytes(lines, [v & 0xFF for v in bx])
    emit_bytes(lines, [(v >> 8) & 0xFF for v in bx])
    lines.append("back_dy:")
    emit_bytes(lines, [v & 0xFF for v in by])
    emit_bytes(lines, [(v >> 8) & 0xFF for v in by])

    lines.append("lorry_sprites:")
    for i in range(8):
        data = lorry_orientation(i * 45)
        data += [0x40] * (32 - len(data))          # pad each slot to 32
        lines.append("; heading %d" % (i * 45))
        emit_bytes(lines, data)

    lines.append("icon_sprites:")
    for k in ("start", "phone", "load", "unload", "pause", "resign"):
        lines.append("; %s" % k)
        emit_bytes(lines, icon(k))

    lines.append("wheel_sprite:")
    emit_bytes(lines, wheel())

    os.makedirs(DATA, exist_ok=True)
    open(os.path.join(DATA, "gfx.s"), "w").write("\n".join(lines) + "\n")
    print("wrote data/gfx.s")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
