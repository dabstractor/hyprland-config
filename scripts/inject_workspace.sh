#!/usr/bin/env bash

set -e

# --- Dependency Check ---
if ! command -v jq &> /dev/null; then
    hyprctl notify -1 5000 "rgb(ff4444)" "Error: jq is not installed."
    exit 1
fi

# --- Argument Parsing ---
MODE=$1
if [[ "$MODE" != "before" && "$MODE" != "after" ]]; then
    echo "Usage: $0 [before|after]"
    exit 1
fi

# --- Core Function: Shift Workspaces Up ---
# This function now correctly finds the gap and shifts the block of workspaces.
shift_workspaces_up() {
    local start_id=$1

    # 1. Get the full JSON of all workspaces.

    occupied_workspaces_json=$(hyprctl workspaces -j)

    # 2. Find the first empty workspace ID ("the gap") starting from start_id.
    #    We use 'jq -e' which exits with status 0 if it finds a match.
    local gap_id=$start_id
    while echo "$occupied_workspaces_json" | jq -e --argjson id "$gap_id" '.[] | select(.id == $id)' > /dev/null; do
        gap_id=$((gap_id + 1))
    done

    # 3. Get the block of workspaces to shift (from start_id to just before the gap).
    #    We operate on the full JSON and extract the IDs at the end.
    local workspaces_to_shift
    workspaces_to_shift=$(echo "$occupied_workspaces_json" | jq -r --argjson start "$start_id" --argjson gap "$gap_id" '[.[] | select(.id >= $start and .id < $gap)] | sort_by(.id) | reverse | .[].id')

    if [[ -z "$workspaces_to_shift" ]]; then
        return # Nothing to do
    fi

    # 4. Move windows from each workspace in the block to the next one up.
    for id in $workspaces_to_shift; do
        local target_id=$((id + 1))
        window_addresses=$(hyprctl clients -j | jq -r --argjson id "$id" '.[] | select(.workspace.id == $id) | .address')
        for addr in $window_addresses; do
            hyprctl dispatch movetoworkspace "$target_id,address:$addr"
        done
    done
}


# --- Main Logic ---

active_state_json=$(hyprctl -j activewindow)
active_workspace_id=$(echo "$active_state_json" | jq .workspace.id)
active_window_address=$(echo "$active_state_json" | jq -r .address)

if [[ -z "$active_workspace_id" || "$active_workspace_id" == "null" || "$active_window_address" == "null" ]]; then
    hyprctl notify -1 5000 "rgb(ff4444)" "Inject-Workspace: Could not find active window/workspace!"
    exit 1
fi

if [[ "$MODE" == "after" ]]; then
    # --- "After" Logic ---
    target_workspace_id=$((active_workspace_id + 1))

    if hyprctl workspaces -j | jq -e ".[] | select(.id == $target_workspace_id and .windows > 0)" > /dev/null; then
        shift_workspaces_up "$target_workspace_id"
    fi

    hyprctl --batch "\
        dispatch movetoworkspace $target_workspace_id,address:$active_window_address;\
        dispatch workspace $target_workspace_id"

elif [[ "$MODE" == "before" ]]; then
    # --- "Before" Logic ---
    target_for_others=$((active_workspace_id + 1))

    shift_workspaces_up "$target_for_others"

    unfocused_addresses=$(hyprctl clients -j | jq -r --argjson ws_id "$active_workspace_id" --arg addr "$active_window_address" '.[] | select(.workspace.id == $ws_id and .address != $addr) | .address')

    if [[ -n "$unfocused_addresses" ]]; then
        for addr in $unfocused_addresses; do
            hyprctl dispatch movetoworkspace "$target_for_others,address:$addr"
        done
    fi

    hyprctl dispatch workspace "$active_workspace_id"
fi
