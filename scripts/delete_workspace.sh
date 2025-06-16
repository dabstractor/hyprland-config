#!/usr/bin/env bash

#
# delete-workspace.sh (v3 - Corrected Behavior)
#
# Leaves the current workspace untouched and shifts all subsequent
#  workspaces down by one, starting from the NEXT workspace.
#

set -e

# --- Dependency Check ---
if ! command -v jq &> /dev/null; then
    hyprctl notify -1 5000 "rgb(ff4444)" "Error: jq is not installed."
    exit 1
fi

# --- Core Function: Shift Workspaces Down (Unchanged) ---
# This function is correct and does not need to be modified.
shift_workspaces_down() {
    local start_id=$1

    workspaces_to_shift=$(hyprctl workspaces -j | jq -r --argjson start "$start_id" '[.[] | select(.id >= $start and .windows > 0)] | sort_by(.id) | .[].id')

    if [[ -z "$workspaces_to_shift" ]]; then
        return
    fi

    for id in $workspaces_to_shift; do
        local target_id=$((id - 1))
        window_addresses=$(hyprctl clients -j | jq -r --argjson id "$id" '.[] | select(.workspace.id == $id) | .address')
        for addr in $window_addresses; do
            hyprctl dispatch movetoworkspace "$target_id,address:$addr"
        done
    done
}


# --- Main Logic (CORRECTED BEHAVIOR) ---

active_workspace_id=$(hyprctl activeworkspace -j | jq .id)

# 1. Define the starting point for the shift as the NEXT workspace.
shift_start_id=$((active_workspace_id + 1))

# 2. Call the shift function to pull all subsequent workspaces down by one.
shift_workspaces_down "$shift_start_id"

# 3. Move focus to the workspace that received the windows.
hyprctl dispatch workspace "$active_workspace_id"
