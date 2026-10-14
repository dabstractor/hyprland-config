#!/usr/bin/env bash
# Brave profile picker (bound to ALT+SUPER+P in custom/keybinds.lua).
#
# Lists every valid profile from Brave's "Local State"; profiles that already
# have a live browser instance (detected via fds the running brave processes
# hold open inside each profile directory) are tagged "[open]" but still
# selectable — picking one opens a new window in that profile.
set -euo pipefail

BRAVE_DIR="$HOME/.config/BraveSoftware/Brave-Browser"
LOCAL_STATE="$BRAVE_DIR/Local State"

# Profiles with a running instance: any brave process holding fds into the dir.
running_profiles() {
	local p
	for p in $(pgrep -x brave 2>/dev/null); do
		ls -l "/proc/$p/fd" 2>/dev/null || true
	done | grep -oE "Brave-Browser/[^/]+/" \
		| sed -e 's|^Brave-Browser/||' -e 's|/$||' | sort -u
}

sel="$(
	running_profiles | python3 -c '
import json, os, sys
state = json.load(open(sys.argv[1]))
running = set(l for l in sys.stdin.read().splitlines() if l.strip())
base = sys.argv[2]
lines = []
for d, info in state["profile"]["info_cache"].items():
    # ghost/corrupt registry entries: skip keys that would break menu lines
    # or that point at a directory missing from disk
    if "\n" in d or "/" in d or not os.path.isdir(os.path.join(base, d)):
        continue
    name = (info.get("name") or d).strip() or d
    name = " ".join(name.split())  # collapse stray whitespace/control chars
    tag = " [open]" if d in running else ""
    lines.append(f"{name}{tag} ({d})")
for line in sorted(lines, key=str.casefold):
    print(line)
' "$LOCAL_STATE" "$BRAVE_DIR" | fuzzel --match-mode fzf --dmenu --prompt='brave profile ❯ ' || true
)"
[ -n "$sel" ] || exit 0

dir="$(sed -n 's/^.* (\(.*\))$/\1/p' <<<"$sel" | head -1)"
# unparseable selection: bail rather than launch with an empty
# --profile-directory (which drops brave on the profile-chooser screen)
[ -n "$dir" ] || exit 1
exec brave --remote-debugging-port=9222 "--profile-directory=$dir"
