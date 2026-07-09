#!/usr/bin/env bash
#
# refresh-pointer-focus.sh
#
# Force Hyprland to re-resolve seat "pointer focus" for the surface currently
# under the cursor. This fixes the "can't scroll after switching workspaces
# until I wiggle the mouse" issue without any visible cursor movement.
#
# Why this works:
#   `hyprctl dispatch movecursor X Y` is not a plain warp. In Hyprland's
#   Actions::moveCursor() it calls BOTH warpCursorTo() AND
#   g_pInputManager->simulateMouseMovement(), the latter being what re-resolves
#   which surface receives pointer/scroll events. A real mouse wiggle does the
#   same thing; this just does it without you having to touch the mouse.
#
# We nudge the cursor a couple of px and move it straight back to "home" so the
# net displacement is zero.
#
# Tune via env:  JIGGLE_PX=2
set -euo pipefail

DISPLACE="${JIGGLE_PX:-2}"

# `hyprctl cursorpos` prints global logical coords like:  1921, 1058
pos="$(hyprctl cursorpos)"
pos="${pos//,/}"                 # drop the comma -> "1921 1058"
read -r X Y <<<"$pos"

# Bail cleanly on a malformed read rather than warping to 0,0.
[[ "$X" =~ ^[0-9]+$ && "$Y" =~ ^[0-9]+$ ]] || exit 0

# force=true inside the dispatcher already bypasses cursor:no_warps, so this is
# safe even if you ever set that option.
hyprctl --batch \
  "dispatch movecursor $((X + DISPLACE)) $Y ; dispatch movecursor $X $Y" \
  >/dev/null 2>&1 || true
