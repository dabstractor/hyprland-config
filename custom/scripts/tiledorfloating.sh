#!/usr/bin/env bash

# Run a different hyprctl dispatch based on whether the active window is floating or tiled.
#
# Usage:
#   $0 "<command_for_floating_window>" "<command_for_tiled_window>"
#
# Positionally-locked scratchpads (matched by initialTitle) are never moved —
# e.g. the "terminal" scratchpad should stay put instead of sliding around on
# Super+Ctrl+scroll. Add more space-separated initialTitles to LOCKED_TITLES as needed.

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 \"<command_for_floating>\" \"<command_for_tiled>\"" >&2
    exit 1
fi

FLOATING_CMD=$1
TILED_CMD=$2

# Space-separated initialTitles that must never be moved by this script.
LOCKED_TITLES="terminal"

WIN=$(hyprctl activewindow -j)
TITLE=$(printf '%s' "$WIN" | jq -r '.initialTitle // .title // ""')

for t in $LOCKED_TITLES; do
    if [ "$TITLE" = "$t" ]; then
        # Locked in place: do nothing.
        exit 0
    fi
done

if printf '%s' "$WIN" | jq -e '.floating' >/dev/null; then
    hyprctl dispatch "$FLOATING_CMD"
else
    hyprctl dispatch "$TILED_CMD"
fi
