#!/bin/sh
# run.sh [wait] [out.png]
# Boot build/juggernaut.tap in Oricutron (Atmos, fast tape, autoload) and
# grab its window.  OCDIR holds the data files (roms/, tapes/);
# OCBIN is the emulator binary (the app bundle is x86-only).
WAIT=${1:-8}
OUT=${2:-/tmp/juggernaut.png}
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OCDIR=${OCDIR:-$HOME/Downloads/Oricutron_osx_v09}
OCBIN=${OCBIN:-$HOME/RiderProjects/oricutron/oricutron}
TAP="$ROOT/build/juggernaut.tap"

pkill -x oricutron 2>/dev/null
sleep 1
( cd "$OCDIR" && "$OCBIN" -R soft -m atmos -k none --turbotape on -t "$TAP" -a \
    >/tmp/oricutron.log 2>&1 & )
sleep 1
osascript -e 'tell application "System Events" to set frontmost of every process whose name is "oricutron" to true' >/dev/null 2>&1
sleep "$WAIT"
"$ROOT/tools/shot.sh" "$OUT"
