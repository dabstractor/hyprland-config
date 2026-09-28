#!/bin/bash
# Exits 0 iff NO non-headless (physical) Hyprland is currently running.
# Used by the VNC session's autostarts to skip per-user singletons
# (syncthing, keyring, portals, clipboard watchers) that a concurrently
# running physical session already owns. Supported flow: physical first,
# VNC second. If the VNC session started first, the physical session's own
# autostarts are responsible for their own single-instancing.
for h in $(pgrep -x Hyprland 2>/dev/null); do
	if ! tr '\0' '\n' < "/proc/$h/environ" 2>/dev/null | grep -q '^WLR_BACKENDS=headless$'; then
		exit 1
	fi
done
exit 0
