#!/usr/bin/env python3
"""
pointer-focus-listener.py

Watches Hyprland's IPC socket2 and nudges the cursor (via
refresh-pointer-focus.sh) whenever the focused/visible surface changes, so seat
"pointer focus" is re-resolved and scroll/axis events keep working.

Problem: after a workspace switch (esp. empty->filled), a monitor focus change,
or a special-workspace toggle, the compositor's pointer focus can be left stale.
Scroll events then go nowhere until the mouse is physically moved.
  https://github.com/hyprwm/Hyprland/discussions/14767

A button click no longer rescues you (a click only refocuses when the window
under the cursor differs from the keyboard-focused window), so we do it
automatically. `movecursor` runs simulateMouseMovement(), which always
re-resolves pointer focus -- same code path as a real mouse wiggle.

Tunable via environment:
  JIGGLE_DEBOUNCE  seconds to collapse event bursts into one jiggle  (default 0.08)
  JIGGLE_SETTLE    seconds to wait after an event before jiggling    (default 0.03)
  JIGGLE_SCRIPT    path to the jiggle helper
"""

from __future__ import annotations

import itertools
import os
import socket
import subprocess
import sys
import threading
import time

HERE = os.path.dirname(os.path.realpath(__file__))
JIGGLE_SCRIPT = os.environ.get(
    "JIGGLE_SCRIPT", os.path.join(HERE, "refresh-pointer-focus.sh")
)

# socket2 emits "<event>>>payload". These are the events that can leave pointer
# focus out of sync with what's now on screen.
TRIGGER_EVENTS = {
    "workspace",      # active workspace changed (primary trigger)
    "focusedmon",     # focus moved to another monitor
    "activespecial",  # special workspace opened/closed
    "moveworkspace",  # workspace relocated to another monitor
}

DEBOUNCE_S = float(os.environ.get("JIGGLE_DEBOUNCE", "0.08"))
SETTLE_S = float(os.environ.get("JIGGLE_SETTLE", "0.03"))

_lock = threading.Lock()
_last_run = 0.0


def log(msg: str) -> None:
    print(f"[pointer-focus] {msg}", file=sys.stderr, flush=True)


def jiggle() -> None:
    try:
        subprocess.run(
            [JIGGLE_SCRIPT],
            check=False,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    except Exception as exc:  # noqa: BLE001 - we want to survive any hiccup
        log(f"jiggle failed: {exc}")


def schedule_jiggle() -> None:
    """Collapse bursts (DEBOUNCE) and defer slightly (SETTLE) before nudging."""
    global _last_run
    now = time.monotonic()
    with _lock:
        if now - _last_run < DEBOUNCE_S:
            return
        _last_run = now
    threading.Timer(SETTLE_S, jiggle).start()


def resolve_socket2() -> str | None:
    sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    xdg = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
    if sig:
        return f"{xdg}/hypr/{sig}/.socket2.sock"
    # Fallback: pick the only (or most recent) instance socket.
    base = os.path.join(xdg, "hypr")
    try:
        candidates = [
            os.path.join(base, d, ".socket2.sock")
            for d in os.listdir(base)
            if os.path.exists(os.path.join(base, d, ".socket2.sock"))
        ]
    except FileNotFoundError:
        return None
    if not candidates:
        return None
    return max(candidates, key=os.path.getmtime)


def follow(socket_path: str) -> None:
    while True:
        try:
            sock = socket.socket(socket.AF_UNIX)
            sock.connect(socket_path)
        except OSError as exc:
            log(f"connect failed ({exc}); retrying in 2s")
            time.sleep(2)
            # path may have changed (Hyprland restart); re-resolve.
            new = resolve_socket2() or socket_path
            socket_path = new
            continue

        with sock.makefile("rb") as stream:
            for raw in itertools.chain(iter(stream.readline, b"")):
                line = raw.decode("utf-8", "replace").strip()
                if ">>" not in line:
                    continue
                event = line.split(">>", 1)[0]
                if event in TRIGGER_EVENTS:
                    schedule_jiggle()
        # stream ended: reconnect.
        log("socket2 closed; reconnecting")


def main() -> None:
    socket_path = resolve_socket2()
    if not socket_path or not os.path.exists(socket_path):
        log(f"socket2 not found (resolved: {socket_path!r}); exiting")
        sys.exit(1)
    log(f"listening on {socket_path} (debounce={DEBOUNCE_S}s, settle={SETTLE_S}s)")
    follow(socket_path)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(0)
