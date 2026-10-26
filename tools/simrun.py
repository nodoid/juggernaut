#!/usr/bin/env python3
"""Run the built game on a host 6502 and render what the Oric screen would show.

    tools/simrun.py [--entry SYM] [--steps N] [--out shot.png] [--dump ADDR:LEN]

The tape image is decoded, the payload is loaded at its load address and the
CPU is started at the entry point (default: the label _game_run from the
label file).  Execution stops when the step budget runs out or when the CPU
leaves the program area, which is exactly the runaway-code failure that is
otherwise painful to find in the emulator.  The HIRES area and the three
character rows are then rendered with the ULA's rules:

  * bits 0-5 of a byte are six pixels, bit 5 leftmost;
  * bit 6 clear means the byte is an attribute, not pixels;
  * bit 7 inverts the six pixels.

Requires py65 (pip install py65).
"""
from __future__ import annotations

import argparse
import os
import sys

try:
    from py65.devices.mpu6502 import MPU
except ImportError:                                        # pragma: no cover
    sys.exit("py65 is required: pip install py65")

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
HIRES = 0xA000
TEXTROWS = 0xBF68
CHARSET = 0x9800
PROG_LO, PROG_HI = 0x0500, 0x9800


def load_tap(path: str):
    d = open(path, "rb").read()
    if d[0:3] != b"\x16\x16\x16" or d[3] != 0x24:
        raise SystemExit("not an Oric tape image")
    hdr = d[4:13]
    addr = (hdr[6] << 8) | hdr[7]
    i = 13
    while d[i]:
        i += 1
    return addr, d[i + 1:]


class FakeVIA(bytearray):
    """VIA timer always expired, plus enough of the AY to serve the keyboard.

    The Oric reads the key matrix by putting the row on VIA port B, writing a
    column mask into AY register 14 and reading port B bit 3.  That chain is
    modelled here so a script can hold keys down and drive the game exactly as
    the real machine would.
    """

    def __init__(self, n):
        bytearray.__init__(self, n)
        self.creg = 0                  # AY register currently addressed
        self.ay = bytearray(16)        # AY register file
        self.aymode = 0                # 0 idle, 1 address, 2 write data
        self.porta = 0
        self.orb = 0
        self.pressed = set()           # (row, column) pairs held down
        self.step = 0
        self.schedule = []             # (from_step, to_step, row, col)

    def set_step(self, step):
        self.step = step
        held = set()
        for a, b, r, c in self.schedule:
            if a <= step < b:
                held.add((r, c))
        self.pressed = held

    def key_bit(self):
        row = self.orb & 0x07
        mask = self.ay[14]
        for r, c in self.pressed:
            if r == row and not (mask >> c) & 1:
                return 0x08
        return 0x00

    def __setitem__(self, a, v):
        if a == 0x0300:                # port B: the matrix row
            self.orb = v
        elif a == 0x030F:              # port A: AY data/address
            self.porta = v
        elif a == 0x030C:              # PCR: the AY bus strobes
            if v == 0xFF:
                self.aymode = 1        # BDIR=BC1=1: latch the register number
            elif v == 0xFD:
                self.aymode = 2        # BDIR=1: write the data
            else:
                self.aymode = 0
            if self.aymode == 1:
                self.creg = self.porta & 15
            elif self.aymode == 2 and self.creg < 16:
                self.ay[self.creg] = self.porta
        bytearray.__setitem__(self, a, v)

    def __getitem__(self, a):
        if isinstance(a, int):
            if a == 0x030D:                 # IFR: T1 flag always set
                return 0x40
            if a == 0x0304:                 # T1 counter low: reads clear the flag
                return 0x00
            if a == 0x0300:                 # ORB: bit 3 is the key sense line
                return (self.orb & 0xF7) | self.key_bit()
        return bytearray.__getitem__(self, a)


def load_labels(path: str) -> dict[str, int]:
    out = {}
    if not os.path.exists(path):
        return out
    for line in open(path):
        p = line.split()
        if len(p) == 3 and p[0] == "al":
            out[p[2].lstrip(".")] = int(p[1], 16)
    return out


def render(mem: bytes, path: str) -> None:
    from PIL import Image

    img = Image.new("RGB", (240, 224), (0, 0, 0))
    px = img.load()
    # HIRES: 200 lines
    for y in range(200):
        base = HIRES + y * 40
        for bx in range(40):
            c = mem[base + bx]
            inv = bool(c & 0x80)
            if (c & 0x60) == 0x00:          # attribute byte: not pixels
                continue
            data = c & 0x3F
            for i in range(6):
                on = (data >> (5 - i)) & 1
                if inv:
                    on ^= 1
                px[bx * 6 + i, y] = (255, 255, 0) if on else (0, 0, 0)
    # 3 character rows: on the Oric these are drawn from the ROM character
    # generator at $B400, which the host does not have, so the game's own font
    # stands in for it.
    for row in range(3):
        for col in range(40):
            ch = mem[TEXTROWS + row * 40 + col] & 0x7F
            gl = CHARSET + 0x100 + max(0, ch - 32) * 8
            for line in range(8):
                bits = mem[gl + line]
                inv = bool(ch & 0x80)
                for i in range(6):
                    on = (bits >> (5 - i)) & 1
                    if inv:
                        on ^= 1
                    px[col * 6 + i, 200 + row * 8 + line] = (
                        (255, 255, 0) if on else (0, 0, 0))
    img.save(path)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--tap", default=os.path.join(ROOT, "build", "juggernaut.tap"))
    ap.add_argument("--lbl", default=os.path.join(ROOT, "build", "juggernaut.lbl"))
    ap.add_argument("--entry", default="_game_run")
    ap.add_argument("--steps", type=int, default=400000)
    ap.add_argument("--out", default=os.path.join(ROOT, "build", "sim.png"))
    ap.add_argument("--dump", action="append", default=[])
    ap.add_argument("--press", action="append", default=[],
                    metavar="ROW:COL:FROM:TO",
                    help="hold a key matrix position down between two steps")
    args = ap.parse_args()

    addr, data = load_tap(args.tap)
    labels = load_labels(args.lbl)
    mem = bytearray(0x10000)
    mem[addr:addr + len(data)] = data

    entry = labels.get(args.entry)
    if entry is None:
        raise SystemExit("unknown entry symbol %r" % args.entry)

    mem = FakeVIA(mem)
    mpu = MPU()
    mpu.memory = mem
    mpu.sp = 0xFF
    mpu.pc = entry
    mpu.a = 0
    mpu.x = 0
    mpu.y = 0

    for p in args.press:
        r, c, a, b = (int(x, 0) for x in p.split(":"))
        mem.schedule.append((a, b, r, c))

    steps = 0
    bad = None
    while steps < args.steps:
        pc = mpu.pc
        mem.set_step(steps)
        mpu.step()
        steps += 1
        if not (PROG_LO <= pc < PROG_HI):
            bad = pc
            break
    print("steps=%d pc=$%04X sp=$%02X a=$%02X x=$%02X y=$%02X"
          % (steps, mpu.pc, mpu.sp, mpu.a, mpu.x, mpu.y))
    if bad is not None:
        print("!! execution left the program area at $%04X" % bad)
    for d in args.dump:
        a, n = d.split(":")
        a = int(a, 16)
        n = int(n, 16)
        print("$%04X:" % a, mem[a:a + n].hex())

    render(mem, args.out)
    print("wrote", args.out)
    return 1 if bad is not None else 0


if __name__ == "__main__":
    sys.exit(main())
