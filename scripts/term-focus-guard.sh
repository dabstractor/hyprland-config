#!/usr/bin/env bash
# term-focus-guard.sh
#
# Conditionally keep focus on the floating terminal scratchpad.
#
# A static catch-all `no_initial_focus` rule would also prevent the ONLY window on
# screen from getting focus (you'd have to click into it). That's wrong: we want to
# block focus-theft only WHILE the terminal is visible, and let lone windows focus
# normally when the terminal is hidden.
#
# Static window rules can't express "only while the terminal is up", so this script
# rewrites a sourced config fragment based on the terminal's actual visibility, and
# Hyprland auto-reloads it. Wired to the Alt+Space terminal toggle (and run once at
# startup), so the guard state always matches the terminal state.
#
#   terminal visible -> fragment contains:  windowrule = match:class .*, no_initial_focus on
#   terminal hidden  -> fragment contains:  (commented out; lone windows focus normally)

set -euo pipefail

GUARD="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/custom/term-focus-guard.conf"
RULE='windowrule = match:class .*, no_initial_focus on'
OFF='# terminal scratchpad is hidden — focus guard inactive (lone windows focus normally)'

# The terminal is "visible" when it is mapped and on a regular (non-special) workspace.
# hyprscratch hides it by moving it to a special workspace (id < 0), so this is false then.
if hyprctl clients -j | jq -e \
  '[.[] | select(.title == "terminal" and .mapped == true and .workspace.id > 0)] | length > 0' \
  >/dev/null 2>&1
then
  new="$RULE"
else
  new="$OFF"
fi

# Only rewrite on a state change to avoid needless config reloads.
if [ ! -f "$GUARD" ] || [ "$(cat "$GUARD" 2>/dev/null)" != "$new" ]; then
  printf '%s\n' "$new" > "$GUARD"
fi
