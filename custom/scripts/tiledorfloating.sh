#!/usr/bin/env bash

# Run a different hyprctl dispatch based on whether the active window is floating or tiled.
#
# Usage:
#   $0 "<command_for_floating_window>" "<command_for_tiled_window>"
#
# Windows whose initialTitle is in LOCKED_TITLES are never moved or resized.
# Only the scratchpad terminal is launched with --title "terminal", so this
# locks exactly that one window and nothing else. Add more titles if ever needed.

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 \"<command_for_floating>\" \"<command_for_tiled>\"" >&2
    exit 1
fi

FLOATING_CMD=$1
TILED_CMD=$2

# Space-separated initialTitles that are immune to move/resize.
LOCKED_TITLES="terminal"

WIN=$(hyprctl activewindow -j 2>/dev/null)
TITLE=$(printf '%s' "$WIN" | jq -r '.initialTitle // .title // ""' 2>/dev/null)

for t in $LOCKED_TITLES; do
    if [ "$TITLE" = "$t" ]; then
        exit 0   # locked: do nothing
    fi
done

if printf '%s' "$WIN" | jq -e '.floating' >/dev/null 2>&1; then
    hyprctl dispatch "$FLOATING_CMD"
else
    hyprctl dispatch "$TILED_CMD"
fi
