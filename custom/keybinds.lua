-- Custom keybindings.
-- Reconstructed by hand from the pre-migration keybinds.conf. The end4 default
-- binds live in hyprland/keybinds.lua and are reclaimed via custom/unbinds.lua.

----------------------------------------------------------------------
-- Helpers (replace custom/scripts/tiledorfloating.sh + delete_workspace.sh
-- + inject_workspace.sh, which relied on the now-broken `hyprctl dispatch
-- <name> <params>` form and on jq).
----------------------------------------------------------------------

-- The locked terminal scratchpad is launched with --title "terminal"; it is
-- immune to move/resize. initialTitle is what Hyprland sets at map time.
local function is_locked_terminal(win)
	return win ~= nil and (win.initial_title == "terminal" or win.title == "terminal")
end

-- Resize active window by a relative delta; skip the locked terminal.
-- (Was: tiledorfloating.sh "resizeactive Dx Dy" "resizeactive Dx Dy".)
local function resize_if_ok(dx, dy)
	local w = hl.get_active_window()
	if is_locked_terminal(w) then
		return
	end
	hl.dispatch(hl.dsp.window.resize({ x = dx, y = dy, relative = true }))
end

-- Move the active (floating) window by a relative delta; skip the locked
-- terminal. No-op on tiled windows, matching old `moveactive` behavior.
local function move_if_ok(dx, dy)
	local w = hl.get_active_window()
	if is_locked_terminal(w) then
		return
	end
	hl.dispatch(hl.dsp.window.move({ x = dx, y = dy, relative = true }))
end

-- Floating -> move by delta; Tiled -> focus in a direction. Skip locked terminal.
-- (Was: tiledorfloating.sh "moveactive Dx Dy" "movefocus <dir>".)
local function move_or_focus(dx, dy, direction)
	local w = hl.get_active_window()
	if is_locked_terminal(w) then
		return
	end
	if w and w.floating then
		hl.dispatch(hl.dsp.window.move({ x = dx, y = dy, relative = true }))
	else
		hl.dispatch(hl.dsp.focus({ direction = direction }))
	end
end

-- First workspace id >= start_id that does not exist (the "gap").
local function first_empty_workspace(start_id)
	local occupied = {}
	for _, ws in ipairs(hl.get_workspaces()) do
		occupied[ws.id] = true
	end
	local gap = start_id
	while occupied[gap] do
		gap = gap + 1
	end
	return gap
end

-- Snapshot every workspace in [lo, gap) with its window addresses, then move
-- each workspace's windows up by one — highest id first so a move never lands
-- in a workspace we still have to process.
local function shift_workspaces_up(lo)
	local gap = first_empty_workspace(lo)
	local snapshot = {}
	for _, ws in ipairs(hl.get_workspaces()) do
		if ws.id >= lo and ws.id < gap then
			local addrs = {}
			for _, w in ipairs(ws:get_windows()) do
				table.insert(addrs, w.address)
			end
			snapshot[ws.id] = addrs
		end
	end
	local ids = {}
	for id, _ in pairs(snapshot) do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		return a > b
	end)
	for _, id in ipairs(ids) do
		local target = id + 1
		for _, addr in ipairs(snapshot[id]) do
			hl.dispatch(hl.dsp.window.move({
				workspace = target,
				window = "address:" .. addr,
				follow = false,
			}))
		end
	end
end

-- Pull every occupied workspace after the active one down by one, then refocus.
-- (Was: custom/scripts/delete_workspace.sh.)
local function delete_workspace()
	local aws = hl.get_active_workspace()
	if not aws then
		return
	end
	local active_id = aws.id
	local shift_start = active_id + 1

	local to_shift = {}
	for _, ws in ipairs(hl.get_workspaces()) do
		if ws.id >= shift_start and ws.windows > 0 then
			local addrs = {}
			for _, w in ipairs(ws:get_windows()) do
				table.insert(addrs, w.address)
			end
			table.insert(to_shift, { id = ws.id, addrs = addrs })
		end
	end
	table.sort(to_shift, function(a, b)
		return a.id < b.id
	end)
	for _, entry in ipairs(to_shift) do
		local target = entry.id - 1
		for _, addr in ipairs(entry.addrs) do
			hl.dispatch(hl.dsp.window.move({
				workspace = target,
				window = "address:" .. addr,
				follow = false,
			}))
		end
	end
	hl.dispatch(hl.dsp.focus({ workspace = active_id }))
end

-- "after": open a gap right after the active window's workspace and move the
-- active window into it. "before": isolate the active window on its own workspace
-- by pushing everything else on it up by one. (Was: inject_workspace.sh.)
local function inject_workspace(mode)
	local aw = hl.get_active_window()
	if not aw or not aw.workspace then
		return
	end
	local active_ws = aw.workspace
	local active_id = active_ws.id
	local active_addr = aw.address

	if mode == "after" then
		local target = active_id + 1
		for _, ws in ipairs(hl.get_workspaces()) do
			if ws.id == target and ws.windows > 0 then
				shift_workspaces_up(target)
				break
			end
		end
		hl.dispatch(hl.dsp.window.move({
			workspace = target,
			window = "address:" .. active_addr,
			follow = false,
		}))
		hl.dispatch(hl.dsp.focus({ workspace = target }))
	elseif mode == "before" then
		local target_for_others = active_id + 1
		shift_workspaces_up(target_for_others)
		local others = {}
		for _, w in ipairs(active_ws:get_windows()) do
			if w.address ~= active_addr then
				table.insert(others, w.address)
			end
		end
		for _, addr in ipairs(others) do
			hl.dispatch(hl.dsp.window.move({
				workspace = target_for_others,
				window = "address:" .. addr,
				follow = false,
			}))
		end
		hl.dispatch(hl.dsp.focus({ workspace = active_id }))
	end
end

----------------------------------------------------------------------
-- Workspace switching (relative selectors MUST be strings in 0.55)
----------------------------------------------------------------------

hl.bind("SUPER + L", hl.dsp.focus({ workspace = "+1" }))
hl.bind("SUPER + H", hl.dsp.focus({ workspace = "-1" }))
hl.bind("SUPER + K", hl.dsp.focus({ workspace = "-5" }))
hl.bind("SUPER + J", hl.dsp.focus({ workspace = "+5" }))

hl.bind("SUPER + mouse_up", hl.dsp.focus({ workspace = "+1" }))
hl.bind("SUPER + mouse_down", hl.dsp.focus({ workspace = "-1" }))
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

hl.bind("SUPER + SHIFT + mouse_down", hl.dsp.window.move({ workspace = "-1" }))
hl.bind("SUPER + SHIFT + mouse_up", hl.dsp.window.move({ workspace = "+1" }))

-- Move focus
hl.bind("CTRL + SUPER + H", hl.dsp.focus({ direction = "left" }))
hl.bind("CTRL + SUPER + L", hl.dsp.focus({ direction = "right" }))
hl.bind("CTRL + SUPER + K", hl.dsp.focus({ direction = "up" }))
hl.bind("CTRL + SUPER + J", hl.dsp.focus({ direction = "down" }))

-- Cycle windows (history-based, like Alt+Tab)
hl.bind("SUPER + Tab", hl.dsp.window.cycle_next())
hl.bind("SUPER + SHIFT + Tab", hl.dsp.window.cycle_next({ prev = true }))

-- Move windows (tiled) / Focus windows (floating)
hl.bind("CTRL + SUPER + mouse_down", function()
	move_or_focus(-40, 0, "left")
end)
hl.bind("CTRL + SUPER + mouse_up", function()
	move_or_focus(40, 0, "right")
end)
hl.bind("CTRL + SUPER + SHIFT + mouse_down", function()
	move_or_focus(0, -40, "up")
end)
hl.bind("CTRL + SUPER + SHIFT + mouse_up", function()
	move_or_focus(0, 40, "down")
end)
hl.bind("CTRL + SUPER + up", function()
	move_or_focus(-40, 0, "left")
end)
hl.bind("CTRL + SUPER + down", function()
	move_or_focus(40, 0, "right")
end)
hl.bind("CTRL + SUPER + SHIFT + up", function()
	move_or_focus(0, -40, "up")
end)
hl.bind("CTRL + SUPER + SHIFT + down", function()
	move_or_focus(0, 40, "down")
end)

-- Swap windows (geometry-preserving: uses `swapwindow`, which only exchanges which
-- window occupies a node, so the current split ratio is kept. Do NOT use `window.move`
-- here -- that dispatches `movewindow`, which removes+reinserts the window and
-- re-reads dwindle:default_split_ratio, snapping every swap back to the default.)
hl.bind("CTRL + ALT + SUPER + H", hl.dsp.window.swap({ direction = "left" }))
hl.bind("CTRL + ALT + SUPER + L", hl.dsp.window.swap({ direction = "right" }))
hl.bind("CTRL + ALT + SUPER + K", hl.dsp.window.swap({ direction = "up" }))
hl.bind("CTRL + ALT + SUPER + J", hl.dsp.window.swap({ direction = "down" }))
hl.bind("CTRL + ALT + SUPER + mouse_down", hl.dsp.window.swap({ direction = "left" }))
hl.bind("CTRL + ALT + SUPER + mouse_up", hl.dsp.window.swap({ direction = "right" }))
hl.bind("CTRL + ALT + SUPER + SHIFT + mouse_down", hl.dsp.window.swap({ direction = "up" }))
hl.bind("CTRL + ALT + SUPER + SHIFT + mouse_up", hl.dsp.window.swap({ direction = "down" }))

-- Overdrive volume controls
hl.bind(
	"XF86AudioRaiseVolume",
	hl.dsp.exec_cmd("~/.config/hypr/scripts/increase_volume.sh 5"),
	{ locked = true, repeating = true }
)
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("pamixer --allow-boost -d 5"), { locked = true, repeating = true })

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
	resize_if_ok(-40, 0)
end, { locked = true })
hl.bind("ALT + SUPER + mouse_up", function()
	resize_if_ok(40, 0)
end, { locked = true })
hl.bind("ALT + SHIFT + SUPER + mouse_down", function()
	resize_if_ok(0, -40)
end, { locked = true })
hl.bind("ALT + SHIFT + SUPER + mouse_up", function()
	resize_if_ok(0, 40)
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

-- Show/Hide bar (ags)
hl.bind("ALT + SUPER + Z", hl.dsp.exec_cmd("agsv1 run-js 'toggleBarVisibility();'"))
hl.bind("SUPER + Z", hl.dsp.exec_cmd("agsv1 run-js 'toggleCurrentWorkspaceBarVisibility();'"))

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
hl.bind("ALT + SUPER + g", hl.dsp.global("quickshell:timewarriorEditTags"))

-- Brave profiles
hl.bind("SUPER + P", hl.dsp.exec_cmd("brave --remote-debugging-port=9222 --profile-directory=Profile\\ 0"))
hl.bind("CTRL + SUPER + P", hl.dsp.exec_cmd("brave --remote-debugging-port=9222 --profile-directory=Profile\\ 1"))
hl.bind("ALT + SUPER + P", hl.dsp.exec_cmd("brave --remote-debugging-port=9222 --profile-directory=Profile\\ 2"))
hl.bind("SHIFT + SUPER + P", hl.dsp.exec_cmd("brave --remote-debugging-port=9222 --profile-directory=Profile\\ 8"))
hl.bind(
	"SHIFT + ALT + SUPER + P",
	hl.dsp.exec_cmd("brave --remote-debugging-port=9222 --profile-directory=Profile\\ 3")
)
hl.bind("CTRL + ALT + SUPER + P", hl.dsp.exec_cmd("brave --remote-debugging-port=9222 --profile-directory=Profile\\ 4"))

-- Cycle panel family
hl.bind("SUPER + ALT + Slash", hl.dsp.global("quickshell:panelFamilyCycle"))

-- Voice typing (was: source ~/projects/voice-typing/hypr-binds.conf)
-- hl.bind("CTRL + ALT + SUPER + D", hl.dsp.exec_cmd("/home/dustin/projects/voice-typing/.venv/bin/voicectl toggle"))       -- big model (distil-large-v3 + small.en)
hl.bind("SUPER + ALT + D", hl.dsp.exec_cmd("/home/dustin/projects/voice-typing/.venv/bin/voicectl toggle-lite")) -- little/lite model (small.en only)

hl.bind("SUPER + e", hl.dsp.global("quickshell:overviewEmojiToggle"))
