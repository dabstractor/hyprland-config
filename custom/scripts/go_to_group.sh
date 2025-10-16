
#!/bin/bash

# Navigates to a specific workspace group, maintaining the relative
# index (1-10) of the current workspace.
# Takes one argument: the target group number (1, 2, 3, ...).
# Groups are numbered starting from 1:
#   Group 1: Workspaces 1-10
#   Group 2: Workspaces 11-20
#   Group 3: Workspaces 21-30
#   ...etc.
#
# Examples:
# - If current workspace is 13 (index 3 in Group 2), running "$0 1" goes to workspace 3 (index 3 in Group 1).
# - If current workspace is 5 (index 5 in Group 1), running "$0 3" goes to workspace 25 (index 5 in Group 3).
# - If current workspace is 20 (index 10 in Group 2), running "$0 1" goes to workspace 10 (index 10 in Group 1).

# --- Configuration ---
GROUP_SIZE=10

# --- Input Validation ---
if [ -z "$1" ]; then
  echo "Usage: $0 <target_group_number>"
  echo "Example: $0 1  (goes to the corresponding workspace in Group 1: 1-10)"
  echo "Example: $0 3  (goes to the corresponding workspace in Group 3: 21-30)"
  exit 1
fi

# Validate the input argument is a positive integer
if ! [[ "$1" =~ ^[1-9][0-9]*$ ]]; then
  echo "Error: Target group number must be a positive integer (1, 2, 3...)."
  exit 1
fi

# Target group number (1-based) from the script argument
target_group_num=$1
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
# Calculate the relative index (1-10) of the current workspace within its group.
# Example:
#   active_workspace=5  -> (5-1)%10 + 1 = 4%10 + 1 = 5
#   active_workspace=10 -> (10-1)%10 + 1 = 9%10 + 1 = 10
#   active_workspace=13 -> (13-1)%10 + 1 = 12%10 + 1 = 3
#   active_workspace=20 -> (20-1)%10 + 1 = 19%10 + 1 = 10
current_rel_index=$(( (active_workspace - 1) % GROUP_SIZE + 1 ))

# Calculate the base workspace ID for the target group (0, 10, 20, ...)
# Target group number is 1-based, so subtract 1 before multiplying.
# Example:
#   target_group_num=1 -> (1-1)*10 = 0
#   target_group_num=2 -> (2-1)*10 = 10
#   target_group_num=3 -> (3-1)*10 = 20
target_group_base=$(( (target_group_num - 1) * GROUP_SIZE ))

# Calculate the final target workspace ID
new_workspace=$(( target_group_base + current_rel_index ))

# --- Execution ---
# Dispatch the command to switch workspace using hyprctl
# echo "Current: $active_workspace, Relative Index: $current_rel_index, Target Group: $target_group_num, Target Base: $target_group_base, New: $new_workspace" # Uncomment for debugging
hyprctl dispatch workspace "$new_workspace"

exit 0
