#!/bin/bash

# Navigates to a workspace within the *current* group of 10.
# Takes one argument: the target workspace number within the group (1-10).
# Groups are numbered starting from 1:
#   Group 1: Workspaces 1-10
#   Group 2: Workspaces 11-20
#   Group 3: Workspaces 21-30
#   ...etc.
#
# Examples:
# - If current workspace is in Group 1 (1-10), running "$0 10" goes to workspace 10.
# - If current workspace is in Group 2 (11-20), running "$0 10" goes to workspace 20.
# - If current workspace is in Group 1 (1-10), running "$0 3" goes to workspace 3.
# - If current workspace is in Group 2 (11-20), running "$0 3" goes to workspace 13.

# --- Configuration ---
GROUP_SIZE=10

# --- Input Validation ---
if [ -z "$1" ]; then
  echo "Usage: $0 <target_workspace_1_to_${GROUP_SIZE}>"
  echo "Example: $0 10  (goes to 10, 20, 30... depending on current group)"
  echo "Example: $0 3   (goes to 3, 13, 23... depending on current group)"
  exit 1
fi

# Validate the input argument is a number between 1 and GROUP_SIZE
if ! [[ "$1" =~ ^[0-9]+$ ]] || [ "$1" -lt 1 ] || [ "$1" -gt "$GROUP_SIZE" ]; then
  echo "Error: Target workspace must be a number between 1 and ${GROUP_SIZE}."
  exit 1
fi

# Target relative workspace (1-10) from the script argument
target_rel=$1

# --- Get Current State ---
# Get the current active workspace ID using hyprctl and jq
active_workspace=$(hyprctl activeworkspace -j | jq -r .id)

# Check if hyprctl command was successful and returned a valid number
if [ -z "$active_workspace" ] || ! [[ "$active_workspace" =~ ^[0-9]+$ ]]; then
    echo "Error: Could not determine active workspace ID."
    echo "Ensure hyprctl and jq are installed and hyprland is running."
    exit 1
fi

# --- Calculation ---
# Calculate the base of the current workspace group (0, 10, 20, ...)
# This uses integer division and relates to the 1-based group number:
#   Group 1 (Workspaces 1-10):  Base = ((1..10 - 1) / 10) * 10 = 0
#   Group 2 (Workspaces 11-20): Base = ((11..20 - 1) / 10) * 10 = 10
#   Group 3 (Workspaces 21-30): Base = ((21..30 - 1) / 10) * 10 = 20
workspace_base=$(( (active_workspace - 1) / GROUP_SIZE * GROUP_SIZE ))

# Calculate the target absolute workspace ID by adding the relative target to the base
new_workspace=$(( workspace_base + target_rel ))

# --- Execution ---
# Dispatch the command to switch workspace using hyprctl
# echo "Current: $active_workspace, Target Relative: $target_rel, Base: $workspace_base, New: $new_workspace" # Uncomment for debugging
hyprctl dispatch workspace "$new_workspace"

exit 0
