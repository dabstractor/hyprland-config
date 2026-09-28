#!/usr/bin/env bash
# Ensure the qmk-win libvirt VM (qemu:///system) is running, so that Looking
# Glass has something to attach to when the Super+R scratchpad toggles.
# Invoked fire-and-forget from the Super+R bind in custom/hyprscratch.lua.
#
# Passwordless via /etc/sudoers.d/qmk-win (grants `virsh start` + `virsh
# domstate` for this VM ONLY -- pinned arguments, no wildcards). `sudo -n`
# fails fast instead of hanging on a password prompt should that rule ever be
# removed.
#
# We only START when the domain is "shut off". A cold boot takes a while, so we
# do NOT block the keybind: Looking Glass (scratchpad option: persist) keeps
# retrying its IVSHMEM connection and latches on once the VM finishes booting.

set -u

VM="qmk-win"

state="$(sudo -n virsh domstate "$VM" 2>/dev/null | tr -d '[:space:]')"

case "$state" in
	running)
		: # already up -- nothing to do
		;;
	"shut off")
		if sudo -n virsh start "$VM" >/dev/null 2>&1; then
			notify-send -a Hyprland \
				"qmk-win VM starting" "Looking Glass will connect once it boots."
		else
			notify-send -u critical -a Hyprland \
				"qmk-win VM failed to start" "Run manually: sudo virsh start $VM"
		fi
		;;
	*)
		# paused / pmsuspended / crashed / unknown -- best-effort start, stay quiet.
		sudo -n virsh start "$VM" >/dev/null 2>&1 || true
		;;
esac
