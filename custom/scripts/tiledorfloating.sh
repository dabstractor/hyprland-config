#!/usr/bin/env bash

# Run a different hyprctl dispatch based on whether the active window is floating or tiled.
# Windows whose initialTitle is in LOCKED_TITLES are never moved/resized.
# Temp diagnostic log at /tmp/torf.log — remove once settled.

LOG=/tmp/torf.log
log(){ printf '%s | %s\n' "$(date '+%H:%M:%S.%3N')" "$*" >> "$LOG"; }

if [ "$#" -ne 2 ]; then log "BADARGS: $*"; exit 1; fi
FLOATING_CMD=$1; TILED_CMD=$2
LOCKED_TITLES="terminal"

WIN=$(hyprctl activewindow -j 2>/dev/null)
TITLE=$(printf '%s' "$WIN" | jq -r '.initialTitle // .title // ""' 2>/dev/null)
FLOATING=$(printf '%s' "$WIN" | jq -r '.floating // false' 2>/dev/null)
log "called [$FLOATING_CMD]/[$TILED_CMD] title=[$TITLE] floating=[$FLOATING]"

for t in $LOCKED_TITLES; do
    if [ "$TITLE" = "$t" ]; then log "LOCKED -> skip"; exit 0; fi
done

if [ "$FLOATING" = "true" ]; then log "-> dispatch $FLOATING_CMD"; hyprctl dispatch "$FLOATING_CMD"
else log "-> dispatch $TILED_CMD"; hyprctl dispatch "$TILED_CMD"; fi
