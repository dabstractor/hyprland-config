-- Custom keybindings.
-- Reconstructed by hand from the pre-migration keybinds.conf. The end4 default
-- binds live in hyprland/keybinds.lua and are reclaimed via custom/unbinds.lua.

----------------------------------------------------------------------
-- Helpers live in custom/lib/ (mirrors the base config's hyprland/lib/).
-- This file is binds only; alias what each domain exports so bind bodies
-- below read as they always did. (Replaced the old custom/scripts/*.sh
-- helpers, which relied on the now-broken `hyprctl dispatch <name> <params>`
-- form and on jq.)
----------------------------------------------------------------------
local win = require("custom.lib.windows")
local ws = require("custom.lib.workspaces")

local resize_if_ok = win.resize_if_ok
local move_if_ok = win.move_if_ok
local move_or_focus = win.move_or_focus
local cycle_fs_aware = win.cycle_fs_aware
local zoomfunction = win.zoomfunction
local carry_window = ws.carry_window
local inject_workspace = ws.inject_workspace
local delete_workspace = ws.delete_workspace

----------------------------------------------------------------------
-- Workspace switching (relative selectors MUST be strings in 0.55)
----------------------------------------------------------------------

hl.bind("SUPER + L", hl.dsp.focus({ workspace = "+1" }))
hl.bind("SUPER + H", hl.dsp.focus({ workspace = "-1" }))
hl.bind("SUPER + K", hl.dsp.focus({ workspace = "-5" }))
hl.bind("SUPER + J", hl.dsp.focus({ workspace = "+5" }))

hl.bind("SUPER + mouse_up", hl.dsp.focus({ workspace = "-1" }))
hl.bind("SUPER + mouse_down", hl.dsp.focus({ workspace = "+1" }))
hl.bind("SUPER + mouse_left", hl.dsp.focus({ workspace = "-1" }))
hl.bind("SUPER + mouse_right", hl.dsp.focus({ workspace = "+1" }))
hl.bind("SUPER + down", hl.dsp.focus({ workspace = "+1" }))
hl.bind("SUPER + up", hl.dsp.focus({ workspace = "-1" }))

-- Normal (non-scratchpad) terminal: separate window + its own tmux "aux"
-- session, independent of the scratchpad's "main" session. Good for demos.
hl.bind("SUPER + SHIFT + Return", hl.dsp.exec_cmd("alacritty -e tmux new-session -A -s aux"))

-- Send active window to an adjacent workspace (was: hyprctl dispatch movetoworkspace).
hl.bind("SUPER + SHIFT + H", hl.dsp.window.move({ workspace = "-1" }))
hl.bind("SUPER + SHIFT + L", hl.dsp.window.move({ workspace = "+1" }))
hl.bind("SUPER + SHIFT + J", hl.dsp.window.move({ workspace = "+5" }))
hl.bind("SUPER + SHIFT + K", hl.dsp.window.move({ workspace = "-5" }))

-- Scroll-wheel window carrying (SUPER+SHIFT+wheel): debounced, fires ONE
-- movetoworkspace ±N after scrolling settles (rationale in custom/lib/
-- workspaces.lua). Keyboard sends below stay direct — discrete presses.

hl.bind("SUPER + SHIFT + mouse_down", function()
	carry_window(1)
end)
hl.bind("SUPER + SHIFT + mouse_up", function()
	carry_window(-1)
end)

-- Move focus
hl.bind("CTRL + SUPER + H", hl.dsp.focus({ direction = "left" }))
hl.bind("CTRL + SUPER + L", hl.dsp.focus({ direction = "right" }))
hl.bind("CTRL + SUPER + K", hl.dsp.focus({ direction = "up" }))
hl.bind("CTRL + SUPER + J", hl.dsp.focus({ direction = "down" }))

-- Cycle windows (history-based, like Alt+Tab). Implementation (fullscreen-
-- aware: the window we land on inherits the fullscreen/maximized state of the
-- one we left) lives in custom/lib/windows.lua.
hl.bind("SUPER + Tab", function()
	cycle_fs_aware(true)
end)
hl.bind("SUPER + SHIFT + Tab", function()
	cycle_fs_aware(false)
end)

-- Move windows (tiled) / Focus windows (floating)
hl.bind("CTRL + SUPER + mouse_down", function()
	move_or_focus(40, 0, "right")
end)
hl.bind("CTRL + SUPER + mouse_up", function()
	move_or_focus(-40, 0, "left")
end)
hl.bind("CTRL + SUPER + SHIFT + mouse_down", function()
	move_or_focus(0, 40, "down")
end)
hl.bind("CTRL + SUPER + SHIFT + mouse_up", function()
	move_or_focus(0, -40, "up")
end)
hl.bind("CTRL + SUPER + up", function()
	move_or_focus(40, 0, "left")
end)
hl.bind("CTRL + SUPER + down", function()
	move_or_focus(-40, 0, "right")
end)
hl.bind("CTRL + SUPER + SHIFT + up", function()
	move_or_focus(0, 40, "up")
end)
hl.bind("CTRL + SUPER + SHIFT + down", function()
	move_or_focus(0, -40, "down")
end)

-- Swap windows (geometry-preserving: uses `swapwindow`, which only exchanges which
-- window occupies a node, so the current split ratio is kept. Do NOT use `window.move`
-- here -- that dispatches `movewindow`, which removes+reinserts the window and
-- re-reads dwindle:default_split_ratio, snapping every swap back to the default.)
hl.bind("CTRL + ALT + SUPER + H", hl.dsp.window.swap({ direction = "left" }))
hl.bind("CTRL + ALT + SUPER + L", hl.dsp.window.swap({ direction = "right" }))
hl.bind("CTRL + ALT + SUPER + K", hl.dsp.window.swap({ direction = "up" }))
hl.bind("CTRL + ALT + SUPER + J", hl.dsp.window.swap({ direction = "down" }))
hl.bind("CTRL + ALT + SUPER + mouse_down", hl.dsp.window.swap({ direction = "right" }))
hl.bind("CTRL + ALT + SUPER + mouse_up", hl.dsp.window.swap({ direction = "left" }))
hl.bind("CTRL + ALT + SUPER + SHIFT + mouse_down", hl.dsp.window.swap({ direction = "down" }))
hl.bind("CTRL + ALT + SUPER + SHIFT + mouse_up", hl.dsp.window.swap({ direction = "up" }))

-- Volume/mute keys -- routed through custom/scripts/volume-keys.sh (moved
-- here from hyprland/keybinds.lua, end4 dir). Physical session: wpctl,
-- byte-identical to the original end4 binds. VNC session: pactl over the
-- ssh reverse tunnel to the client laptop + thinclient_osd mirror sync
-- (see the script). These replace the old "overdrive" binds.
hl.bind(
	"XF86AudioRaiseVolume",
	hl.dsp.exec_cmd("~/.config/hypr/custom/scripts/volume-keys.sh up"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioLowerVolume",
	hl.dsp.exec_cmd("~/.config/hypr/custom/scripts/volume-keys.sh down"),
	{ locked = true, repeating = true }
)
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("~/.config/hypr/custom/scripts/volume-keys.sh mute"), { locked = true })
hl.bind(
	"SUPER + SHIFT + M",
	hl.dsp.exec_cmd("~/.config/hypr/custom/scripts/volume-keys.sh mute"),
	{ locked = true, description = "Media: Toggle mute" }
)
hl.bind(
	"ALT + XF86AudioMute",
	hl.dsp.exec_cmd("~/.config/hypr/custom/scripts/volume-keys.sh mic-mute"),
	{ locked = true }
)
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("~/.config/hypr/custom/scripts/volume-keys.sh mic-mute"), { locked = true })
hl.bind(
	"SUPER + ALT + M",
	hl.dsp.exec_cmd("~/.config/hypr/custom/scripts/volume-keys.sh mic-mute"),
	{ locked = true, description = "Media: Toggle mic" }
)

-- Resize windows — routed through resize_if_ok so the locked terminal is skipped.
hl.bind("SUPER + Minus", function()
	resize_if_ok(0, -40)
end, { locked = true, repeating = true })
hl.bind("SUPER + Equal", function()
	resize_if_ok(0, 40)
end, { locked = true, repeating = true })
hl.bind("SUPER + Comma", function()
	resize_if_ok(-40, 0)
end, { locked = true, repeating = true })
hl.bind("SUPER + Period", function()
	resize_if_ok(40, 0)
end, { locked = true, repeating = true })

hl.bind("ALT + SUPER + mouse_down", function()
	resize_if_ok(40, 0)
end, { locked = true })
hl.bind("ALT + SUPER + mouse_up", function()
	resize_if_ok(-40, 0)
end, { locked = true })
hl.bind("ALT + SHIFT + SUPER + mouse_down", function()
	resize_if_ok(0, 40)
end, { locked = true })
hl.bind("ALT + SHIFT + SUPER + mouse_up", function()
	resize_if_ok(0, -40)
end, { locked = true })

-- Move windows — routed through move_if_ok so the locked terminal is skipped.
hl.bind("CTRL + SUPER + Minus", function()
	move_if_ok(0, -8)
end, { locked = true, repeating = true })
hl.bind("CTRL + SUPER + Equal", function()
	move_if_ok(0, 8)
end, { locked = true, repeating = true })
hl.bind("CTRL + SUPER + Comma", function()
	move_if_ok(-8, 0)
end, { locked = true, repeating = true })
hl.bind("CTRL + SUPER + Period", function()
	move_if_ok(8, 0)
end, { locked = true, repeating = true })

-- Cursor zoom (screen magnifier centered on the cursor; zoom_rigid = false so
-- the magnified region tracks the cursor). The end4 default SUPER+-/= zoom
-- binds were reclaimed above for resize; these replace them. Impl in
-- custom/lib/windows.lua (zoomfunction).
hl.bind("SUPER + ALT + Minus", function()
	zoomfunction(-0.3)
end, { repeating = true, description = "Screen: Zoom out" })
hl.bind("SUPER + ALT + Equal", function()
	zoomfunction(0.3)
end, { repeating = true, description = "Screen: Zoom in" })

-- Launcher
hl.bind("SUPER + Space", hl.dsp.exec_cmd("vicinae toggle"))

-- Super + left-drag to move (float) windows. This is an end4 default
-- (hyprland/keybinds.lua binds SUPER+mouse:272 -> window.drag), but
-- unbinds.lua clears the whole SUPER+mouse:* namespace to reclaim it; re-bind
-- it here so drag-to-move survives (only the side buttons 275/276 are reclaimed
-- below for workspace injection).
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true })

-- Workspace injection / deletion (native; was inject_workspace.sh / delete_workspace.sh)
hl.bind("SUPER + mouse:275", function()
	inject_workspace("before")
end)
hl.bind("SUPER + mouse:276", function()
	inject_workspace("after")
end)
hl.bind("SUPER + delete", function()
	delete_workspace()
end)

-- Sleep
hl.bind("SUPER + SHIFT + Delete", hl.dsp.exec_cmd("systemctl suspend || loginctl suspend"), { locked = true })

-- Timewarrior
hl.bind("SUPER + g", hl.dsp.global("quickshell:timewarriorStartOrStop"))
hl.bind("SUPER + ALT + g", hl.dsp.global("quickshell:timewarriorEditTags"))

-- Brave profiles
-- SUPER+P: default launch (Profile 0, "Dmanke main")
hl.bind("SUPER + P", hl.dsp.exec_cmd("brave --remote-debugging-port=9222 --profile-directory=Profile\\ 0"))
-- CTRL+SUPER+P: secondary profile ("Dustin D Schultz", Profile 4)
hl.bind(
	"CTRL + SUPER + P",
	hl.dsp.exec_cmd("brave --remote-debugging-port=9222 --profile-directory=Profile\\ 4"),
	{ description = "Brave: Dustin D Schultz profile" }
)
-- ALT+SUPER+P: profile picker (fuzzel menu; hides profiles with open windows).
-- No other profile has a dedicated hotkey — reachable via the picker.
hl.bind(
	"ALT + SUPER + P",
	hl.dsp.exec_cmd("$HOME/.config/hypr/custom/scripts/brave-profile-picker.sh"),
	{ description = "Brave: profile picker" }
)

-- Cycle panel family
hl.bind("SUPER + ALT + Slash", hl.dsp.global("quickshell:panelFamilyCycle"))

-- Voice typing (was: source ~/projects/voice-typing/hypr-binds.conf)
-- big model (distil-large-v3 + small.en); moved here from the tail of
-- hyprland/keybinds.lua (end4 dir).
hl.bind(
	"CTRL + SUPER + ALT + D",
	hl.dsp.exec_cmd("$HOME/.local/bin/voicectl toggle"),
	{ description = "Voice: Toggle dictation (big model)" }
)
-- lite model (small.en only). Robust toggle (fixes silent no-op over VNC + after session flaps):
--  1) ensures the daemon is up: voice-typing.service is PartOf=graphical-session.target,
--     which headless VNC sessions never activate, and physical-session logouts stop it;
--  2) pins XDG_RUNTIME_DIR to the systemd --user manager's runtime (/run/user/$(id -u)),
--     where the daemon's control socket ALWAYS lives. The exec env inherits the session's
--     runtime dir instead (e.g. /run/user/1000/ghd under VNC) and voicectl would search
--     that, find no socket, and exit 2 ("daemon not running") even with the daemon up;
--  3) waits (<=5 s, 0.1 s polls) for the socket so systemctl's async cold start cannot
--     race the toggle. Identical behavior in physical and VNC sessions; errors flow to
--     the session journal for future diagnosis.
hl.bind(
	"SUPER + ALT + D",
	hl.dsp.exec_cmd(
		'RD="/run/user/$(id -u)"; '
			.. 'XDG_RUNTIME_DIR="$RD" systemctl --user start voice-typing.service; '
			.. 'S="$RD/voice-typing/control.sock"; i=0; '
			.. 'while [ "$i" -lt 50 ] && [ ! -S "$S" ]; do sleep 0.1; i=$((i+1)); done; '
			.. 'XDG_RUNTIME_DIR="$RD" /home/dustin/projects/voice-typing/.venv/bin/voicectl toggle-lite'
	)
) -- little/lite model (small.en only)

hl.bind("SUPER + E", hl.dsp.global("quickshell:overviewEmojiToggle"))

----------------------------------------------------------------------
-- Dwindle split-direction toggle
----------------------------------------------------------------------

-- SUPER+ALT+S was "Window: Send to scratchpad" (hyprland/keybinds.lua);
-- re-purposed per user instruction. Needs dwindle.preserve_split = true
-- (already set globally).
hl.unbind("SUPER + ALT + S")
hl.bind("SUPER + ALT + S", hl.dsp.layout("togglesplit"), { description = "Dwindle: toggle split direction" })

-- NOTE: SUPER+Tab used to ALSO bind quickshell:cyclenext here. Identical
-- duplicate binds BOTH fire in 0.56 (no last-wins), so Super+Tab was
-- double-cycling; removed in favor of the fullscreen-aware cycle_fs_aware
-- bind above. ALT+SUPER+Tab keeps the quickshell overview.
hl.bind(
	"ALT + SUPER + Tab",
	hl.dsp.global("quickshell:overviewWorkspacesToggle"),
	{ description = "Shell: Toggle overview" }
)

-- dlna video picker: ephemeral floating alacritty, fresh instance every
-- press, dies after selection (window rule in custom/rules.lua)
hl.bind(
	"ALT + SUPER + T",
	hl.dsp.exec_cmd("alacritty --title dlna-picker -e dlna"),
	{ description = "dlna: video picker" }
)

-- mpv: pause every running mpv at once (O: right-hand key, layer-safe per the
-- QMK rule; script: ~/.local/bin/mpv-pause-all, sockets from mpv's
-- scripts/auto-ipc.lua)
hl.bind("SUPER + grave", function()
	hl.dispatch(hl.dsp.focus({ workspace = workspace_in_group(1) }))
	hl.exec_cmd("mpv-pause-all")
end, { description = "mpv: pause all instances, jump to workspace 1 in group" })

-- Window-leader mode (SUPER+W -> encoder resize, mirroring neovim's <C-w>).
-- Loaded last and guarded by pcall so an error in winmode.lua can never take
-- the rest of these custom binds down with it.
pcall(require, "custom.winmode")
