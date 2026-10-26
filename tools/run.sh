#!/bin/sh
# run.sh [wait] [out.png]
# Boot build/juggernaut.tap in Oricutron (Atmos, autoload) and grab the window.
#
#   OCDIR  directory holding the Oricutron data files (roms/, tapes/)
#   OCBIN  the emulator binary; the 0.9 .app bundle is x86 only, so this
#          defaults to a native build next to this repository
WAIT=${1:-8}
OUT=${2:-/tmp/juggernaut.png}
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OCDIR=${OCDIR:-$HOME/Downloads/Oricutron_osx_v09}
OCBIN=${OCBIN:-$HOME/RiderProjects/oricutron/oricutron}
TAP="$ROOT/build/juggernaut.tap"

pkill -x oricutron 2>/dev/null
sleep 1
( cd "$OCDIR" && nohup "$OCBIN" -R soft -m atmos -k none -t "$TAP" -a \
    </dev/null >/tmp/oricutron.log 2>&1 & )
sleep "$WAIT"
"$ROOT/tools/shot.sh" "$OUT"
