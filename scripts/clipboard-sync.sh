#!/bin/bash

# Alternative clipboard sync script using wl-clipboard-x11
# This script tries different methods to sync Wayland to X11

LOG_FILE="$HOME/.cache/clipboard-sync-v2.log"

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

log "Starting alternative clipboard sync daemon"

# Test if wl-clipboard-x11 is available
if command -v wl-clipboard-x11 >/dev/null 2>&1; then
    log "wl-clipboard-x11 found - using compatibility mode"

    # Method 1: Use wl-clipboard-x11 as compatibility layer
    export PATH="/usr/bin/wl-clipboard-x11:$PATH"
fi

while true; do
    # Check if there's image content in Wayland clipboard
    if wl-paste --list-types 2>/dev/null | grep -q "image/"; then
        log "Detected image content in Wayland clipboard"

        # Try multiple sync methods

        # Method 1: Direct wl-copy to X11 clipboard
        if wl-paste --type image/png 2>/dev/null | wl-copy --selection "clipboard" 2>/dev/null; then
            log "Method 1 successful: wl-copy sync"
        else
            log "Method 1 failed"

            # Method 2: Use xclip if available
            if command -v xclip >/dev/null 2>&1; then
                if wl-paste --type image/png 2>/dev/null | xclip -selection clipboard -t image/png 2>/dev/null; then
                    log "Method 2 successful: xclip sync"
                else
                    log "Method 2 failed"
                fi
            fi
        fi

        # Wait a bit to avoid rapid loops
        sleep 2
    else
        sleep 0.5
    fi
done