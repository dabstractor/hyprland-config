#!/bin/bash

# Timewarrior idle pause/resume script
# Usage: ./timew-idle.sh [pause|resume]
#
# This script handles pausing and resuming timewarrior sessions
# when the system goes idle and becomes active again.

FLAG_FILE="$HOME/.cache/timew_idle_paused"
LOG_FILE="$HOME/.cache/timew_idle.log"

# Function to log actions
log_action() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Function to pause timewarrior
pause_timew() {
    # Check if timewarrior is currently running
    if timew > /dev/null 2>&1; then
        # Get current timewarrior info before stopping
        timew > /tmp/timew_state_before_pause

        # Stop timewarrior and save the state
        timew stop

        # Create flag file to indicate we paused due to idle
        echo "$(date '+%Y-%m-%d %H:%M:%S')" > "$FLAG_FILE"

        log_action "Timewarrior paused due to system idle"
    else
        log_action "Timewarrior not running, no action needed"
    fi
}

# Function to resume timewarrior
resume_timew() {
    # Check if we have a pause flag file
    if [ -f "$FLAG_FILE" ]; then
        # Read the pause time
        PAUSE_TIME=$(cat "$FLAG_FILE")

        # Check if timewarrior is currently running first
        if timew > /dev/null 2>&1; then
            log_action "Timewarrior already running, not resuming"
            rm "$FLAG_FILE"
            return
        fi

        # Get the most recent tag from timewarrior export (second to last line = newest entry)
        LAST_TAG=$(timew export | tail -2 | head -1 | sed 's/^{[^}]*"tags":\["\([^"]*\)"[^}]*}$/\1/' 2>/dev/null)

        # If that fails, try a simpler approach
        if [ -z "$LAST_TAG" ]; then
            LAST_TAG=$(timew export | tail -2 | head -1 | grep -o '"tags":\[[^]]*\]' | sed 's/"tags":\[//;s/\]//;s/"//g' | cut -d',' -f1)
        fi

        if [ -n "$LAST_TAG" ] && [ "$LAST_TAG" != "null" ]; then
            timew start "$LAST_TAG"
            log_action "Timewarrior resumed with tag '$LAST_TAG' after idle since $PAUSE_TIME"
        else
            log_action "Could not determine last timewarrior tag to resume"
        fi

        # Remove the flag file
        rm "$FLAG_FILE"
    else
        log_action "No idle pause flag found, not resuming"
    fi
}

# Main script logic
case "$1" in
    "pause")
        pause_timew
        ;;
    "resume")
        resume_timew
        ;;
    *)
        echo "Usage: $0 [pause|resume]"
        echo "  pause  - Stop timewarrior and create pause flag"
        echo "  resume - Resume timewarrior if paused due to idle"
        exit 1
        ;;
esac