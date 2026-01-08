#!/usr/bin/env bash

#
# hyprwait.sh
#
# Wraps a command with an idle inhibitor to prevent hypridle from triggering
# idle actions (lock, dpms off, suspend) until the command completes.
#
# Usage:
#   hyprwait <command> [args...]
#
# Example:
#   hyprwait rsync -av /src /dest
#   hyprwait ffmpeg -i input.mp4 output.webm
#

set -e

if [ $# -eq 0 ]; then
    echo "Usage: hyprwait <command> [args...]" >&2
    exit 1
fi

exec systemd-inhibit \
    --what=idle \
    --who="hyprwait" \
    --why="User initiated command: $1" \
    -- "$@"
