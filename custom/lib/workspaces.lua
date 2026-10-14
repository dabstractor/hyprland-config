-- Workspace-level helpers for the custom config. Pure logic; binds stay in
-- custom/keybinds.lua. (Replaced custom/scripts/delete_workspace.sh +
-- inject_workspace.sh, which relied on the broken `hyprctl dispatch` form and
-- jq.)
local M = {}

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
function M.delete_workspace()
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
function M.inject_workspace(mode)
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
-- Scroll-wheel window carrying (debounced)
----------------------------------------------------------------------

-- carry_window(delta): move the active window `delta` workspaces away, but
-- debounced rather than dispatched per scroll tick. Each movetoworkspace+follow
-- (window.move, custom/keybinds.lua) is a heavy operation: it relocates the
-- window, relayouts, follows onto the target, and replays the
-- workspaces-slide + window-popin animations. Unlike a plain `focus`, those
-- can't be interrupted cleanly mid-flight, so a fast scroll visibly "loads"
-- every intermediate workspace one by one. scroll_event_delay=0 fixed plain
-- focus by killing the input throttle, but movetoworkspace's own per-dispatch
-- cost still serializes. Accumulating the signed delta and firing ONE
-- movetoworkspace ±N shortly after scrolling settles makes the window land
-- exactly N workspaces away in a single transition. Keyboard sends
-- (SHIFT+H/L/J/K in custom/keybinds.lua) stay direct since they're discrete
-- presses, not bursts.
local CARRY_SETTLE_MS = 30
local carry_accumulator = 0
local carry_timer = nil

local function carry_flush()
	carry_timer = nil
	local total = carry_accumulator
	carry_accumulator = 0
	if total ~= 0 then
		hl.dispatch(hl.dsp.window.move({ workspace = (total >= 0 and "+" or "") .. total }))
	end
end

function M.carry_window(delta)
	carry_accumulator = carry_accumulator + delta
	if carry_timer then
		carry_timer:set_enabled(false)
	end
	carry_timer = hl.timer(carry_flush, { timeout = CARRY_SETTLE_MS, type = "oneshot" })
end

return M
