#!/usr/bin/env bash
# Toggle a wf-recorder screen recording (replaces quickshell:regionRecord).
# Press the same key again to stop. Recordings land in /tmp/recordings/.
#
# Usage: record_toggle.sh [--fullscreen] [--sound]
set -u

notify() { command -v notify-send >/dev/null && notify-send -t 3000 "$@" >/dev/null 2>&1 || true; }

fullscreen=no
sound=no
for arg in "$@"; do
	case "$arg" in
	--fullscreen) fullscreen=yes ;;
	--sound) sound=yes ;;
	esac
done

# Second press: stop a running recording (SIGINT lets wf-recorder finalize the file).
if pidof wf-recorder >/dev/null 2>&1; then
	pkill -INT wf-recorder
	notify "Recording" "Stopped and saved"
	exit 0
fi

mkdir -p /tmp/recordings
file="/tmp/recordings/$(date '+%Y-%m-%d_%H.%M.%S').mkv"

args=()
[[ "$sound" == yes ]] && args+=(-a)

if [[ "$fullscreen" == no ]]; then
	geo=$(slurp -d)
	[[ -n "$geo" ]] || exit 0
	args+=(-g "$geo")
fi

# Detach: the recorder must outlive this dispatcher-spawned shell.
nohup wf-recorder "${args[@]}" -f "$file" >/dev/null 2>&1 &
disown

if [[ "$fullscreen" == yes ]]; then
	scope="fullscreen"
else
	scope="region"
fi
if [[ "$sound" == yes ]]; then
	scope="$scope + audio"
fi
notify "Recording" "Recording $scope -> $file (press again to stop)"
