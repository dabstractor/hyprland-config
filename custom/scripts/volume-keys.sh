#!/bin/bash
# Volume/mute keys — SHARED MASTER design (guide §5b):
# One knob = the client laptop's output sink. Remote keys drive it directly
# over the ssh reverse tunnel (pactl -s tcp:127.0.0.1:4713); a display-only
# mirror sink (thinclient_osd, the session's default) is synced afterwards
# so quickshell's OSD/bar shows TRUE values. The ghost tunnel sink stays
# pinned at 100% (no second gain stage). If the tunnel is down, keys no-op
# — matching reality (no speakers reachable).
# Physical session: wpctl as before, byte-identical to the original binds.
set -u
cmd="${1:-}"
LAP="pactl -s tcp:127.0.0.1:4713"

mirror() {
	local v m
	v=$($LAP get-sink-volume @DEFAULT_SINK@ 2>/dev/null | grep -oE '[0-9]+%' | head -1 | tr -d '%')
	m=$($LAP get-sink-mute @DEFAULT_SINK@ 2>/dev/null | grep -oE 'yes|no' | head -1)
	[ -n "$v" ] || return 0
	pactl set-sink-volume thinclient_osd "${v}%" 2>/dev/null || true
	[ -n "$m" ] && pactl set-sink-mute thinclient_osd "$m" 2>/dev/null || true
}

if [ "${WLR_BACKENDS:-}" = "headless" ]; then
	case "$cmd" in
		up) $LAP set-sink-volume @DEFAULT_SINK@ +2% && mirror ;;
		down) $LAP set-sink-volume @DEFAULT_SINK@ -2% && mirror ;;
		mute) $LAP set-sink-mute @DEFAULT_SINK@ toggle && mirror ;;
		mic-mute) pactl set-source-mute thinclient_laptop_mic toggle ;;
	esac
else
	case "$cmd" in
		up) wpctl set-volume @DEFAULT_AUDIO_SINK@ 2%+ -l 1.5 ;;
		down) wpctl set-volume @DEFAULT_AUDIO_SINK@ 2%- ;;
		mute) wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle ;;
		mic-mute) wpctl set-mute @DEFAULT_SOURCE@ toggle ;;
	esac
fi
