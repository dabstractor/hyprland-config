# Quickshell Migration Overview

Status: **capture pipeline fully decoupled** (2026-09-18). Everything else below still
references quickshell and needs migration before `qs` can be removed.

---

## 1. DONE — Capture pipeline (screenshots / OCR / translate / recording)

Replaced with **hyprshot** (grim + slurp + wl-clipboard underneath) and **wf-recorder**,
plus tesseract for OCR. No quickshell involvement.

| Key | Action | Implementation |
|---|---|---|
| `SUPER+SHIFT+S` | Region → clipboard | `hyprshot --mode region --freeze --clipboard-only --silent` |
| `SHIFT+Print` | Region → `/tmp/screenshots` + clipboard | hyprshot `--output-folder` |
| `ALT+Print` | Active window → clipboard | hyprshot `--mode window --mode active` |
| `CTRL+ALT+Print` | Active window → `/tmp/screenshots` + clipboard | 〃 |
| `Print` | Active monitor → clipboard | hyprshot `--mode output --mode active` |
| `CTRL+Print` | Active monitor → `/tmp/screenshots` + clipboard | 〃 |
| `SUPER+SHIFT+X` | Region → OCR → clipboard | `scripts/screenshot_ocr.sh` |
| `SUPER+SHIFT+A` | Region → Google Lens | `scripts/snip_to_search.sh` (unchanged) |
| `SUPER+SHIFT+T` | Region → OCR → translate → clipboard | `scripts/screenshot_translate.sh` |
| `SUPER+SHIFT+R` | Toggle region recording | `scripts/record_toggle.sh` (wf-recorder) |
| `CTRL+ALT+R` | Toggle fullscreen recording | 〃 `--fullscreen` |
| `SUPER+SHIFT+ALT+R` | Toggle fullscreen recording + audio | 〃 `--fullscreen --sound` |

Files: `custom/capture.lua` (binds), `custom/unbinds.lua` (reclaimed the old keys),
`hyprland/scripts/{screenshot_ocr,screenshot_translate,record_toggle}.sh`.
`SUPER+SHIFT+C` (hyprpicker color pick) was already qs-free and is untouched.

Notes:
- hyprshot exits 1 even on success (`checkRunning` ends with `pkill hyprpicker; exit`).
  Ignore the exit code; it is cosmetic and harmless under `exec_cmd`.
- File captures send a notification — you currently have **no notification daemon**
  except quickshell itself. Install one (see below) or they vanish silently.
- Translate needs `translate-shell` (`pacman -S translate-shell`); until then
  `SUPER+SHIFT+T` degrades to plain OCR → clipboard.
- Recordings land in `/tmp/recordings/` (wiped on reboot — change in
  `record_toggle.sh` if you want persistence).

Why hyprshot: wiki's canonical engine is grim+slurp (installed, rock-solid);
hyprshot is the thin, battle-tested wrapper that adds region/window/monitor modes,
clipboard/file handling and freeze. satty/flameshot/HyprCapture are either not
installed, portal-dependent, or too new.

---

## 2. Remaining quickshell dependencies & replacements

### 2.1 Autostart / services (`hyprland/execs.lua`)
| What | Line | Replace with |
|---|---|---|
| `qs -c $qsConfig` (the shell) | execs.lua | see bar/notifications/OSD below |
| `wl-paste --watch … qs ipc call cliphistService update` (×2) | execs.lua | `wl-paste --type text --watch cliphist store` (drop the `&& qs…` tail). Clipboard UI: SUPER+V fallback (cliphist+fuzzel) already works qs-free |

### 2.2 Keybinds (`hyprland/keybinds.lua`, `custom/keybinds.lua`)
| Keys | qs action | Replace with |
|---|---|---|
| `SUPER` (tap) / `SUPER_L`/`SUPER_R` | search toggle | fallback fuzzel already wired; or **anyrun** (installed) |
| `SUPER+V` | clipboard overview | cliphist + fuzzel (fallback already active) |
| `SUPER+Period`, `SUPER+e` | emoji picker | `scripts/fuzzel-emoji.sh` (fallback already active) |
| `SUPER+J` | bar toggle | **waybar** (not installed; also ironbar/nwg-panel) |
| `SUPER+Tab`, `ALT+SUPER+Tab` | overview / cyclenext | **hyprspace** plugin, or drop |
| `SUPER+A`/`B`/`O`, `SUPER+ALT+A`, `SUPER+N` | sidebars | waybar modules or scripts |
| `SUPER+Slash` | cheatsheet | script → `less`/anyrun listing of your binds |
| `SUPER+K` | on-screen keyboard | **squeekboard** / wvkbd (not installed) |
| `SUPER+M` | media controls | playerctl (installed) + fuzzel/anyrun menu script |
| `SUPER+G` | widget overlay | drop |
| session menu bind | sessionToggle | **wlogout** (installed; CTRL+ALT+Delete fallback already uses it) |
| lock bind | qs lock | **hyprlock** (installed) directly |
| `CTRL+SUPER+T`, `CTRL+ALT+SUPER+T` | wallpaper selector / random | `scripts/…/switchwall.sh` fallback + **swaybg** (installed) or swww |
| light/dark toggle | toggleLightDark | script (themes via gsettings/GTK env) |
| `CTRL+SUPER+P`, `SUPER+ALT+Slash` | panel family cycle | drop with qs |
| brightness keys | qs ipc brightness | fallback `brightnessctl` already active |
| `SUPER+g`, `ALT+SUPER+g` | timewarrior | **timew** CLI (installed) + small script |
| `CTRL+SUPER+T`-area "restart widgets" | `killall qs…; qs &` | delete |

### 2.3 Gestures & state (`hyprland/general.lua`, `custom/winmode.lua`)
- Swipe gestures dispatch `quickshell:overviewWorkspacesToggle` (general.lua) →
  remap to workspace switching (`hl.dsp.workspace.switch`) or hyprspace.
- `winmode.lua` calls `qs ipc call workspaceNumbers hide` — remove those lines.

### 2.4 Rules (`hyprland/rules.lua`)
- ~35 `quickshell:*` layer rules (blur, animations, order) — inert once qs is gone;
  delete in the same pass.
- **`quickshell:polkit` is your polkit authentication agent.** Before removing qs,
  install/autostart **hyprpolkitagent** (or lxqt-policykit) or GUI sudo prompts die.

### 2.5 Missing daemons qs currently provides
| Daemon | Install |
|---|---|
| Notifications | `dunst` or `mako` (needed for hyprshot save notifications) |
| OSD (volume/brightness) | `swayosd-ng` |
| Polkit agent | `hyprpolkitagent` |

### 2.6 Not quickshell (leave alone)
`hyprscratch` (separate program), hypridle/hyprlock, kanshi, cliphist storage itself,
fuzzel/anyrun, easyeffects, syncthing, udiskie, vicinae.

---

## 3. Suggested removal order

1. Install dunst/mako + hyprpolkitagent + swayosd; add to `custom/execs.lua`; reboot-test.
2. Rebind lock → hyprlock, session → wlogout, SUPER tap → anyrun/fuzzel (drop `qsIsAlive ||` guards).
3. Migrate bar (waybar) + wallpaper (swaybg/switchwall script); strip sidebar/overview/cheatsheet binds.
4. Clean execs.lua watchers, general.lua gestures, winmode ipc, rules.lua layer rules.
5. `pacman -Rns quickshell` when nothing greps: `grep -rn 'quickshell\|qs -c\|qsIpc' ~/.config/hypr/`.
