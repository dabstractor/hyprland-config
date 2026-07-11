#!/usr/bin/env python3
"""
Route agent-browser's browser windows onto a dedicated Hyprland workspace.

Why this exists
---------------
agent-browser (the CLI pi agents use) drives your *system* Google Chrome, so
its windows share `class=google-chrome` with your personal Chrome. A static
Hyprland window rule can't tell them apart. This listener distinguishes them
reliably by **process ancestry**: every browser agent-browser spawns has an
`agent-browser` process somewhere in its parent chain; your personal Chrome
never does. (Secondary signal: agent-browser always launches Chrome with
`--user-data-dir=/tmp/agent-browser-chrome-<uuid>`.)

When a new browser window opens, if it belongs to agent-browser it is moved
silently (no focus steal, no workspace switch) — keeping your current desktop
uncluttered. The target workspace is chosen per window:

  - if Chrome was launched with `--user-data-dir=<AB_PROFILE_DIR>/<N>` (a
    numbered agent profile), it goes to workspace <N> (e.g. profile 3 -> ws 3);
  - otherwise it falls back to TARGET_WORKSPACE (default 1).

Configuration (env)
-------------------
  AB_WORKSPACE   fallback workspace id/name for non-profile windows (default: 1)
  AB_PROFILE_DIR dir of numbered agent profiles (default: ~/.agent-chrome-profiles)
  AB_DEBUG=1     append a line per decision to ~/.agent-browser/hypr-ws.log
  AB_DRY_RUN=1   detect but never move (for verifying distinguisher)

Usage
-----
  agent-browser-workspace.py            listen on the Hyprland event socket
  agent-browser-workspace.py --sweep    move currently-open agent-browser windows now
  agent-browser-workspace.py --check <addr>   report whether <addr> is an agent-browser window
  agent-browser-workspace.py --selftest       run detection/move logic on one live window

Started automatically by custom/execs.conf via `exec-once`.
"""

import json
import os
import re
import socket
import subprocess
import sys
import time

TARGET_WORKSPACE = os.environ.get("AB_WORKSPACE", "1")
PROFILE_DIR = os.path.expanduser(os.environ.get("AB_PROFILE_DIR", "~/.agent-chrome-profiles"))
DEBUG = os.environ.get("AB_DEBUG") == "1"
DRY_RUN = os.environ.get("AB_DRY_RUN") == "1"
LOGFILE = os.path.expanduser("~/.agent-browser/hypr-ws.log")

# Window classes we consider "a browser worth routing".
BROWSER_CLASSES = {
    "google-chrome", "google-chrome-unstable", "google-chrome-beta",
    "chromium", "chromium-browser", "brave-browser", "microsoft-edge",
    "chrome", "org.chromium.chromium",
}


def log(msg: str) -> None:
    if not DEBUG:
        return
    try:
        os.makedirs(os.path.dirname(LOGFILE), exist_ok=True)
        with open(LOGFILE, "a") as f:
            f.write(f"{time.strftime('%H:%M:%S')} {msg}\n")
    except OSError:
        pass


def hyprctl(*args: str) -> str:
    try:
        return subprocess.run(
            ["hyprctl", *args],
            capture_output=True, text=True, timeout=4,
        ).stdout.strip()
    except Exception as e:
        log(f"hyprctl {args[0]} error: {e}")
        return ""


def canonical_addr(addr: str) -> str:
    """Normalize a Hyprland window address.

    The socket2 `openwindow` event emits addresses WITHOUT a `0x` prefix
    (e.g. `55f21c190790`), while `clients -j` uses the `0x`-prefixed form
    (`0x55f21c190790`). Canonicalize by stripping any `0x` and lowercasing.
    """
    a = (addr or "").strip().lower()
    return a[2:] if a.startswith("0x") else a


def clients_map() -> dict:
    try:
        data = json.loads(hyprctl("clients", "-j"))
        return {canonical_addr(c.get("address")): c for c in data}
    except Exception:
        return {}


def _proc_cmdline(pid: int):
    """Return pid's full cmdline as a string (NULs -> spaces), or None.

    Handles both the normal NUL-separated argv and the space-joined
    single-argv form Chrome sometimes presents under /proc/<pid>/cmdline."""
    try:
        return open(f"/proc/{pid}/cmdline", "rb").read().replace(b"\x00", b" ").decode("utf-8", "replace")
    except OSError:
        return None


def _user_data_dir(cmd):
    """Extract --user-data-dir from a cmdline string
    (--user-data-dir=PATH or --user-data-dir PATH). None if absent."""
    if not cmd:
        return None
    m = re.search(r"--user-data-dir[ =](\S+)", cmd)
    return m.group(1) if m else None


def _ppid(pid: int):
    try:
        m = re.search(r"^PPid:\s+(\d+)", open(f"/proc/{pid}/status").read(), re.M)
        return int(m.group(1)) if m else None
    except OSError:
        return None


def _comm(pid: int) -> str:
    try:
        return open(f"/proc/{pid}/comm").read().strip()
    except OSError:
        return ""


def inspect_window(pid: int):
    """Walk pid + ancestors once. Return (is_agent_browser, user_data_dir).

    is_agent_browser: an ancestor (or self) is an agent-browser process, or a
        cmdline carries the /tmp/agent-browser-chrome marker.
    user_data_dir: the first --user-data-dir found walking up from the window
        (Chrome's main process and its children all carry it).
    """
    is_ab = False
    udd = None
    p = pid
    seen = set()
    while p and p != 1 and p not in seen:
        seen.add(p)
        if "agent-browser" in _comm(p):
            is_ab = True
        cmd = _proc_cmdline(p)
        if cmd is not None:
            if udd is None:
                udd = _user_data_dir(cmd)
            if "agent-browser-chrome" in cmd:
                is_ab = True
        nxt = _ppid(p)
        if nxt is None:
            break
        p = nxt
    return is_ab, udd


def is_agent_browser_window(pid: int) -> bool:
    is_ab, udd = inspect_window(pid)
    return is_ab or is_agent_browser_udd(udd)


def profile_workspace_from_udd(udd):
    """Map a Chrome --user-data-dir to a workspace id if it lives under
    AB_PROFILE_DIR with an integer leaf (e.g. .../.agent-chrome-profiles/3 -> '3').
    Returns None otherwise."""
    if not udd:
        return None
    try:
        base = os.path.realpath(PROFILE_DIR)
        udd_r = os.path.realpath(udd)
    except Exception:
        return None
    try:
        rel = os.path.relpath(udd_r, base)
    except ValueError:
        return None
    if rel == "." or rel == ".." or rel.startswith(".." + os.sep):
        return None
    first = rel.split(os.sep)[0]
    return first if re.fullmatch(r"\d+", first) else None


def is_agent_browser_udd(udd):
    """True if a --user-data-dir value indicates an agent-browser launch:
    its temp profile marker, or any path under AB_PROFILE_DIR.

    Orphan-safe: the cmdline persists after agent-browser's short-lived parent
    process exits and Chrome is reparented to systemd (ancestry alone would
    then miss it)."""
    if not udd:
        return False
    if "agent-browser-chrome" in udd:
        return True
    try:
        base = os.path.realpath(PROFILE_DIR)
        udd_r = os.path.realpath(udd)
        rel = os.path.relpath(udd_r, base)
        if rel != "." and rel != ".." and not rel.startswith(".." + os.sep):
            return True
    except Exception:
        pass
    return False


def target_workspace_for(pid: int) -> str:
    """Where an agent-browser window should live: its profile workspace (if
    launched with a numbered profile under AB_PROFILE_DIR), else the default."""
    _ab, udd = inspect_window(pid)
    return profile_workspace_from_udd(udd) or TARGET_WORKSPACE


def move_if_agent_browser(addr: str) -> str:
    """Inspect a just-opened window; if it belongs to agent-browser, move it
    silently to its target workspace (profile workspace, else default).
    `addr` is normalized (no `0x`). Returns a status string."""
    cl = clients_map().get(canonical_addr(addr))
    if not cl:
        return "absent"
    cls = (cl.get("class") or "").lower()
    if cls not in BROWSER_CLASSES:
        return f"non-browser:{cls}"
    pid = cl.get("pid")
    is_ab, udd = inspect_window(pid)
    if not (is_ab or is_agent_browser_udd(udd)):
        log(f"{addr}: class={cls} pid={pid} -> personal browser (left alone)")
        return "personal"
    prof = profile_workspace_from_udd(udd)
    target = prof or TARGET_WORKSPACE
    via = f"profile={prof}" if prof else "default"
    full_addr = cl.get("address")  # 0x-prefixed, as the dispatcher expects
    ws = (cl.get("workspace") or {}).get("name") or (cl.get("workspace") or {}).get("id")
    if str(ws) == str(target):
        log(f"{addr}: class={cls} pid={pid} -> already on {target} ({via})")
        return "already-target"
    if DRY_RUN:
        log(f"{addr}: class={cls} pid={pid} -> DRY-RUN would move {ws}->{target} ({via})")
        return "dry-run"
    hyprctl("dispatch", "movetoworkspacesilent", f"{target},address:{full_addr}")
    log(f"{addr}: class={cls} pid={pid} -> moved {ws}->{target} ({via})")
    return "moved"


def handle_open(addr: str) -> None:
    # clients -j may lag the openwindow event by a few ms; retry briefly so we
    # don't miss the pid on fast maps.
    norm = canonical_addr(addr)
    for _ in range(8):
        status = move_if_agent_browser(norm)
        if status != "absent":
            return
        time.sleep(0.03)
    log(f"{norm}: never appeared in clients (skipped)")


def listen() -> None:
    sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    xdg = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
    sock_path = f"{xdg}/hypr/{sig}/.socket2.sock"
    if not sig or not os.path.exists(sock_path):
        print(f"agent-browser-workspace: Hyprland socket not found ({sock_path}); exiting.", file=sys.stderr)
        sys.exit(1)
    log(f"listener start -> target workspace {TARGET_WORKSPACE} (dry_run={DRY_RUN})")
    while True:
        try:
            s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            s.connect(sock_path)
            s.settimeout(None)
            buf = b""
            while True:
                data = s.recv(4096)
                if not data:
                    break
                buf += data
                while b"\n" in buf:
                    line, buf = buf.split(b"\n", 1)
                    line = line.decode("utf-8", "replace")
                    if line.startswith("openwindow>>"):
                        addr = line[len("openwindow>>"):].split(",", 1)[0]
                        handle_open(addr)
        except Exception as e:
            log(f"listener error: {e}; reconnecting in 2s")
            time.sleep(2)


def sweep() -> None:
    """Move all currently-open agent-browser browser windows to TARGET_WORKSPACE."""
    moved = 0
    for addr, cl in clients_map().items():
        cls = (cl.get("class") or "").lower()
        if cls not in BROWSER_CLASSES:
            continue
        if is_agent_browser_window(cl.get("pid")):
            st = move_if_agent_browser(addr)
            print(f"{addr} ({cls}): {st}")
            if st == "moved":
                moved += 1
    print(f"sweep done: {moved} window(s) moved to their profile/default workspace")


def check(addr: str) -> None:
    cl = clients_map().get(addr)
    if not cl:
        print(f"{addr}: no such window"); return
    is_ab, udd = inspect_window(cl.get("pid"))
    prof = profile_workspace_from_udd(udd)
    print(f"{addr}: class={cl.get('class')} pid={cl.get('pid')} "
          f"agent_browser={is_ab} profile_ws={prof or '-'} "
          f"target_ws={prof or TARGET_WORKSPACE} workspace={cl.get('workspace')}")


def selftest() -> None:
    """Verify detection + move on one live agent-browser window (restores it)."""
    cands = []
    for addr, cl in clients_map().items():
        if (cl.get("class") or "").lower() in BROWSER_CLASSES and is_agent_browser_window(cl.get("pid")):
            cands.append((addr, cl))
    if not cands:
        print("No live agent-browser browser window found to self-test."); return
    addr, cl = cands[0]
    orig = (cl.get("workspace") or {}).get("id")
    target = target_workspace_for(cl.get("pid"))
    print(f"self-test on {addr} class={cl.get('class')} pid={cl.get('pid')} "
          f"(currently ws {orig}, target ws {target})")
    if DRY_RUN:
        print("AB_DRY_RUN set -> not moving"); return
    print("move ->", hyprctl("dispatch", "movetoworkspacesilent", f"{target},address:{addr}"))
    time.sleep(0.2)
    now = clients_map().get(addr, {}).get("workspace", {}).get("id")
    print(f"now on ws {now} (expected {target}) -> {'OK' if str(now)==str(target) else 'FAIL'}")
    print("restore ->", hyprctl("dispatch", "movetoworkspacesilent", f"{orig},address:{addr}"))


def main() -> None:
    args = sys.argv[1:]
    if not args or args[0] == "listen":
        listen()
    elif args[0] == "--sweep":
        sweep()
    elif args[0] == "--check" and len(args) > 1:
        check(args[1])
    elif args[0] == "--selftest":
        selftest()
    else:
        print(__doc__)
        sys.exit(2)


if __name__ == "__main__":
    main()
