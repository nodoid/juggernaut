#!/bin/sh
# shot.sh out.png - grab the Oricutron window.
OUT=${1:-/tmp/juggernaut.png}
W=$(osascript -e 'tell application "System Events" to tell process "oricutron" to get {position, size} of window 1' 2>/dev/null | tr -d ' ')
X=$(echo "$W" | cut -d, -f1)
Y=$(echo "$W" | cut -d, -f2)
WW=$(echo "$W" | cut -d, -f3)
H=$(echo "$W" | cut -d, -f4)
if [ -z "$X" ]; then
  echo "oricutron window not found" >&2
  exit 1
fi
screencapture -x -R"$X,$Y,$WW,$H" "$OUT"
echo "$OUT"
