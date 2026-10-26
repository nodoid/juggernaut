#!/usr/bin/env python3
"""Type into the focused Oricutron window.

The Oric scans its key matrix once per 50Hz frame, so a synthetic key press
that is only a few microseconds long is never seen.  Every key here is held
for HOLD seconds, which is what makes automated typing work at all.

    tools/keys.py 'CLOAD""' --return
"""
from __future__ import annotations

import subprocess
import sys
import time

HOLD = 0.12


def osa(*lines: str) -> None:
    subprocess.run(["osascript", *sum((["-e", l] for l in lines), [])],
                   check=True, capture_output=True)


def applescript_string(key: str) -> str:
    """Escape a key name for embedding in an AppleScript double quoted string."""
    out = []
    for ch in key:
        if ch in ('"', "\\"):
            out.append("\\" + ch)
        else:
            out.append(ch)
    return "".join(out)


def press(key: str) -> None:
    k = applescript_string(key)
    osa(f'tell application "System Events" to key down "{k}"',
        f'delay {HOLD}',
        f'tell application "System Events" to key up "{k}"')
    time.sleep(0.03)


NAMES = {
    " ": "space",
    "\n": "return",
    "\r": "return",
    "-": "-",
    '"': '"',
    "'": "'",
    "\\": "\\",
}


def main() -> int:
    text = sys.argv[1] if len(sys.argv) > 1 else ""
    for ch in text:
        press(NAMES.get(ch, ch))
    if "--return" in sys.argv:
        press("return")
    return 0


if __name__ == "__main__":
    sys.exit(main())
