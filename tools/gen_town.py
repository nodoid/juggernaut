#!/usr/bin/env python3
"""Generate the town of Scarthorpe.

A cell is one Oric screen byte: 6 pixels across and 8 lines down, which is
also the pixel the HIRES display can address without shifting.  The town is
100 cells by 48 (600 x 384 pixels); the driving view shows 40 x 13 of them.

    python3 tools/gen_town.py

Writes data/town.s and build/town_preview.png.
"""
from __future__ import annotations

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, ".."))
DATA = os.path.join(ROOT, "data")
BUILD = os.path.join(ROOT, "build")

TOWN_W, TOWN_H = 100, 48
ROAD_PX, ROAD_PY = 12, 10          # road every 12 cells across, 10 down
ROAD_W = 2                          # road width in cells

# tile ids
T_ROAD = 0
T_BUILD = 1
T_PAVE = 2
T_BAY = 3
T_MARK_H = 4
T_MARK_G = 5
T_MARK_T = 6
T_MARK_C = 7
T_MARK_O = 8
T_MARK_F = 9
T_MARK_P = 10
T_ZEBRA = 11
T_GRASS = 12
T_ROUND = 13
T_MARK_B = 14

TILE_NAMES = {
    T_ROAD: "T_ROAD", T_BUILD: "T_BUILD", T_PAVE: "T_PAVE", T_BAY: "T_BAY",
    T_MARK_H: "T_MARK_H", T_MARK_G: "T_MARK_G", T_MARK_T: "T_MARK_T",
    T_MARK_C: "T_MARK_C", T_MARK_O: "T_MARK_O", T_MARK_F: "T_MARK_F",
    T_MARK_P: "T_MARK_P", T_ZEBRA: "T_ZEBRA", T_GRASS: "T_GRASS",
    T_ROUND: "T_ROUND", T_MARK_B: "T_MARK_B",
}

# 5x7 letters used inside marker tiles
LETTERS = {
    "H": ("10001", "10001", "10001", "11111", "10001", "10001", "10001"),
    "G": ("01110", "10001", "10000", "10111", "10001", "10001", "01110"),
    "T": ("11111", "00100", "00100", "00100", "00100", "00100", "00100"),
    "C": ("01110", "10001", "10000", "10000", "10000", "10001", "01110"),
    "O": ("01110", "10001", "10001", "10001", "10001", "10001", "01110"),
    "F": ("11111", "10000", "10000", "11110", "10000", "10000", "10000"),
    "P": ("11110", "10001", "10001", "11110", "10000", "10000", "10000"),
    "B": ("11110", "10001", "10001", "11110", "10001", "10001", "11110"),
}


def px(pattern: str) -> int:
    v = 0
    for i, b in enumerate(pattern):
        if b == "1":
            v |= 0x20 >> i
    return v


def tile_rows(kind: int):
    """Eight bytes of six pixels for a tile."""
    if kind == T_ROAD:
        return [0x40] * 8
    if kind == T_BUILD:
        # a roof outline: solid top and bottom, walls down the sides, so the
        # map reads as blocks of buildings rather than a wall of yellow
        return [px("111111"), px("100001"), px("100001"), px("100001"),
                px("100001"), px("100001"), px("111111"), 0x40]
    if kind == T_PAVE:
        return [0x40, 0x40, 0x40, 0x40, 0x40, 0x40, px("101010"), 0x40]
    if kind == T_GRASS:
        return [px("010100"), px("101000"), px("010100"), px("101000"),
                px("010100"), px("101000"), px("010100"), px("101000")]
    if kind == T_BAY:
        return [px("101010"), px("010101"), px("101010"), px("010101"),
                px("101010"), px("010101"), px("101010"), px("010101")]
    if kind == T_ZEBRA:
        return [px("111111"), 0x40, px("111111"), 0x40,
                px("111111"), 0x40, px("111111"), 0x40]
    if kind == T_ROUND:
        return [px("001111"), px("011111"), px("111111"), px("111111"),
                px("111111"), px("111111"), px("111111"), px("111111")]
    letters = {T_MARK_H: "H", T_MARK_G: "G", T_MARK_T: "T", T_MARK_C: "C",
               T_MARK_O: "O", T_MARK_F: "F", T_MARK_P: "P", T_MARK_B: "B"}
    rows = list(LETTERS[letters[kind]])
    out = []
    for r in range(8):
        out.append(px(rows[r]) if r < 7 else 0x40)
    return out


# ---------------------------------------------------------------------------
# Loading bays and their markers.  Every bay is a 4x3 apron inside a building
# block, so it always has a road alongside it.
def bay(block_x, block_y):
    return block_x + 3, block_y + 2


# (name, marker tile, block x, block y)
SITES = [
    ("HOME", T_MARK_H, 27, 23),
    ("TIMBER", T_MARK_T, 15, 13),
    ("COAL", T_MARK_C, 63, 13),
    ("OIL", T_MARK_O, 39, 33),
    ("FRUIT+V", T_MARK_F, 75, 43),
    ("GARAGE1", T_MARK_G, 51, 23),
    ("GARAGE2", T_MARK_G, 87, 33),
    ("GARAGE3", T_MARK_G, 15, 43),
    ("GARAGE4", T_MARK_G, 75, 3),
    ("POLICE1", T_MARK_P, 39, 3),
    ("POLICE2", T_MARK_P, 87, 13),
]

POIS = [(name, kind,) + bay(bx, by) for name, kind, bx, by in SITES]

# phones sit on pavement cells, one block in from a road corner
PHONES = [(3, 6), (24, 6), (48, 16), (72, 16), (12, 26), (60, 26),
          (84, 36), (36, 36), (3, 46), (24, 46)]


def build_town():
    cells = [[T_BUILD] * TOWN_W for _ in range(TOWN_H)]
    for y in range(TOWN_H):
        for x in range(TOWN_W):
            rx = (x - 1) % ROAD_PX
            ry = (y - 1) % ROAD_PY
            if x == 0 or y == 0:
                cells[y][x] = T_ROAD
            elif rx < ROAD_W or ry < ROAD_W:
                cells[y][x] = T_ROAD
            else:
                cells[y][x] = T_BUILD

    # pavements along the buildings, one cell deep
    for y in range(TOWN_H):
        for x in range(TOWN_W):
            if cells[y][x] != T_BUILD:
                continue
            n = [(x + dx, y + dy) for dx, dy in
                 ((1, 0), (-1, 0), (0, 1), (0, -1))]
            if any(0 <= nx < TOWN_W and 0 <= ny < TOWN_H
                   and cells[ny][nx] == T_ROAD for nx, ny in n):
                cells[y][x] = T_PAVE

    # a park and a couple of zebra crossings for variety
    for y in range(14, 19):
        for x in range(50, 58):
            cells[y][x] = T_GRASS
    for (x, y) in ((25, 9), (37, 19), (61, 29), (75, 9)):
        for i in range(ROAD_W):
            cells[y][x + i] = T_ZEBRA
    # roundabouts where the two ring roads cross
    for (cx, cy) in ((13, 11), (85, 31)):
        for dy in range(-1, 3):
            for dx in range(-1, 3):
                x, y = cx + dx, cy + dy
                if 0 <= x < TOWN_W and 0 <= y < TOWN_H:
                    cells[y][x] = T_ROUND

    # loading bays: a 4x3 apron beside a road, with the marker in the middle
    for name, kind, cx, cy in POIS:
        for dy in range(3):
            for dx in range(4):
                x, y = cx + dx, cy + dy
                if 0 <= x < TOWN_W and 0 <= y < TOWN_H:
                    cells[y][x] = T_BAY
        cells[cy + 1][cx + 1] = kind

    for (x, y) in PHONES:
        if 0 <= x < TOWN_W and 0 <= y < TOWN_H:
            cells[y][x] = T_MARK_B
    return cells


def write_town(cells, path: str) -> None:
    lines = ["; generated by tools/gen_town.py - do not edit",
             "        .export town_cells, town_w, town_h, tile_data, poi_tab, poi_count",
             "        .export phones, phone_count",
             "        .segment \"RODATA\"",
             "town_w:   .byte %d" % TOWN_W,
             "town_h:   .byte %d" % TOWN_H,
             "town_cells:"]
    for y in range(TOWN_H):
        row = ",".join("%d" % v for v in cells[y])
        lines.append("        .byte " + row + "        ; row %d" % y)

    lines.append("tile_data:")
    for k in sorted(TILE_NAMES):
        lines.append("; %s" % TILE_NAMES[k])
        lines.append("        .byte " + ",".join("$%02X" % (0x40 | v)
                                                 for v in tile_rows(k)))
    lines.append("poi_count: .byte %d" % len(POIS))
    lines.append("poi_tab:")
    # 4 bytes per poi: cell x, cell y, tile kind, name index
    for i, (name, kind, cx, cy) in enumerate(POIS):
        lines.append("        .byte %d,%d,%d,%d    ; %s" % (cx, cy, kind, i, name))
    lines.append("poi_names:")
    for i, (name, kind, cx, cy) in enumerate(POIS):
        lines.append("        .byte \"%s\",0" % name)
    lines.append("phone_count: .byte %d" % len(PHONES))
    lines.append("phones:")
    for (x, y) in PHONES:
        lines.append("        .byte %d,%d" % (x, y))
    open(path, "w").write("\n".join(lines) + "\n")


def preview(cells, path: str) -> None:
    from PIL import Image
    img = Image.new("RGB", (TOWN_W * 6, TOWN_H * 8), (0, 0, 0))
    px_ = img.load()
    for y in range(TOWN_H):
        for x in range(TOWN_W):
            rows = tile_rows(cells[y][x])
            for ry in range(8):
                bits = rows[ry]
                for i in range(6):
                    on = (bits >> (5 - i)) & 1
                    px_[x * 6 + i, y * 8 + ry] = (255, 255, 0) if on else (0, 0, 0)
    os.makedirs(BUILD, exist_ok=True)
    img.save(path)


def main() -> int:
    cells = build_town()
    os.makedirs(DATA, exist_ok=True)
    write_town(cells, os.path.join(DATA, "town.s"))
    preview(cells, os.path.join(BUILD, "town_preview.png"))
    print("wrote data/town.s (%dx%d cells) and build/town_preview.png"
          % (TOWN_W, TOWN_H))
    return 0


if __name__ == "__main__":
    sys.exit(main())
