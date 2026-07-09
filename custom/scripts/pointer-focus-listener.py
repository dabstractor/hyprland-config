#!/usr/bin/env python3
"""
pointer-focus-listener.py

Watches Hyprland's IPC socket2 and nudges the cursor (via
refresh-pointer-focus.sh) whenever pointer focus could have gone stale, so
scroll/axis events keep working without a manual mouse wiggle.

When does pointer focus go stale?
  Any time the *focused window* changes without the mouse moving:
    - workspace switch (esp. empty -> filled)
      https://github.com/hyprwm/Hyprland/discussions/14767
    - movefocus / cyclenext / Super+Tab (your pane-nav keybinds)
    - focus moving to another monitor
    - special-workspace toggle

Triggers:
  * workspace / focusedmon / activespecial / moveworkspace -> always jiggle
  * activewindowv2 -> jiggle ONLY when the focused window ADDRESS changes.
    Hyprland re-emits activewindow/activewindowv2 on every title or class
    change of the *already-active* window (e.g. a terminal title updating per
    command). Deduping by address means those don't twitch the cursor; only a
    real focus switch to a different window does.

Tunable via environment:
  JIGGLE_DEBOUNCE  seconds to collapse event bursts into one jiggle  (default 0.08)
  JIGGLE_SETTLE    seconds to wait after an event before jiggling    (default 0.03)
  JIGGLE_SCRIPT    path to the jiggle helper
"""

from __future__ import annotations

import itertools
import json
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

# Events that always indicate a possible stale-pointer-focus state.
TRIGGER_EVENTS = {
    "workspace",      # active workspace changed
    "focusedmon",     # focus moved to another monitor
    "activespecial",  # special workspace opened/closed
    "moveworkspace",  # workspace relocated to another monitor
}

DEBOUNCE_S = float(os.environ.get("JIGGLE_DEBOUNCE", "0.08"))
SETTLE_S = float(os.environ.get("JIGGLE_SETTLE", "0.03"))

_lock = threading.Lock()
_last_run = 0.0
_last_addr: str | None = None  # last focused window address (for activewindowv2 dedup)


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
    except Exception as exc:  # noqa: BLE001 - survive any hiccup
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


def on_event(event: str, payload: str) -> None:
    global _last_addr
    if event in TRIGGER_EVENTS:
        schedule_jiggle()
    elif event == "activewindowv2":
        # Jiggle only on a real focus switch (address changed), never on a
        # mere title/class refresh of the same window.
        addr = payload.strip()
        if addr != _last_addr:
            _last_addr = addr
            schedule_jiggle()


def init_known_address() -> None:
    """Seed the known focused-window address so the first event isn't a phantom."""
    global _last_addr
    try:
        out = subprocess.run(
            ["hyprctl", "activewindow", "-j"],
            capture_output=True, text=True, timeout=2,
        )
        data = json.loads(out.stdout or "{}")
        _last_addr = (data.get("address") or "").strip()
    except Exception:
        _last_addr = ""


def resolve_socket2() -> str | None:
    sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    xdg = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
    if sig:
        return f"{xdg}/hypr/{sig}/.socket2.sock"
    # Fallback: pick the most recent instance socket.
    base = os.path.join(xdg, "hypr")
    try:
        candidates = [
            os.path.join(base, d, ".socket2.sock")
            for d in os.listdir(base)
            if os.path.exists(os.path.join(base, d, ".socket2.sock"))
        ]
    except FileNotFoundError:
        return None
    return max(candidates, key=os.path.getmtime) if candidates else None


def follow(socket_path: str) -> None:
    while True:
        try:
            sock = socket.socket(socket.AF_UNIX)
            sock.connect(socket_path)
        except OSError as exc:
            log(f"connect failed ({exc}); retrying in 2s")
            time.sleep(2)
            socket_path = resolve_socket2() or socket_path  # may have changed
            continue

        with sock.makefile("rb") as stream:
            for raw in itertools.chain(iter(stream.readline, b"")):
                line = raw.decode("utf-8", "replace").strip()
                if ">>" not in line:
                    continue
                event, _, payload = line.partition(">>")
                on_event(event, payload)
        log("socket2 closed; reconnecting")


def main() -> None:
    socket_path = resolve_socket2()
    if not socket_path or not os.path.exists(socket_path):
        log(f"socket2 not found (resolved: {socket_path!r}); exiting")
        sys.exit(1)
    init_known_address()
    log(f"listening on {socket_path} (debounce={DEBOUNCE_S}s, settle={SETTLE_S}s, addr={_last_addr})")
    follow(socket_path)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(0)
