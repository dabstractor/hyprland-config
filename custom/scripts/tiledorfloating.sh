#!/usr/bin/env bash

# Script to run a different hyprctl command based on whether the active window is floating or tiled.
#
# Usage:
# ./conditional_action.sh "<command_for_floating_window>" "<command_for_tiled_window>"

# Check for the correct number of arguments.
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 \"<command_for_floating>\" \"<command_for_tiled>\""
    exit 1
fi

FLOATING_CMD=$1
TILED_CMD=$2

# We use `hyprctl activewindow -j` which outputs in JSON format.
# `jq -e '.floating'` checks if the 'floating' key exists and is 'true'.
# The '-e' flag sets the exit code to 0 if the last output was not 'false' or 'null', which is perfect for an if-statement.
if hyprctl activewindow -j | jq -e '.floating'; then
    echo "Window is floating" >> ~/focusorresize.log
    # Window is floating, execute the first command.
    hyprctl dispatch "$FLOATING_CMD"
else
    echo "Window is tiled" >> ~/focusorresize.log
    # Window is tiled, execute the second command.
    hyprctl dispatch "$TILED_CMD"
fi
