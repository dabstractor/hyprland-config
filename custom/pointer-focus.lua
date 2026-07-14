-- Native Lua pointer-focus listener.
--
-- Replaces custom/scripts/pointer-focus-listener.py and refresh-pointer-focus.sh
-- (a long-running Python daemon + shell helper that shelled out to the now-broken
-- `hyprctl dispatch movecursor`). Uses the 0.55 event + query APIs directly.
--
-- After events that can leave seat "pointer focus" stale (workspace switch,
-- focus moving to another monitor, special-workspace toggle, window focus
-- change) we nudge the cursor a couple of px and straight back. In Hyprland this
-- re-resolves which surface receives pointer/scroll events, fixing the "can't
-- scroll after switching workspaces until I wiggle the mouse" issue
-- (hyprwm/Hyprland#14767) with zero net cursor displacement.
--
-- Tunable via env: JIGGLE_PX, JIGGLE_DEBOUNCE, JIGGLE_SETTLE.

local DISPLACE = tonumber(os.getenv("JIGGLE_PX") or "2")
local DEBOUNCE_MS = math.floor((tonumber(os.getenv("JIGGLE_DEBOUNCE") or "0.08") or 0.08) * 1000)
local SETTLE_MS = math.floor((tonumber(os.getenv("JIGGLE_SETTLE") or "0.03") or 0.03) * 1000)
-- Collapse any burst within this window into a single jiggle at the end.
local COALESCE_MS = DEBOUNCE_MS + SETTLE_MS

local armed = false

local function jiggle()
	local pos = hl.get_cursor_pos()
	local x, y = pos.x, pos.y
	-- Nudge then return home: net displacement is zero.
	hl.dispatch(hl.dsp.cursor.move({ x = x + DISPLACE, y = y }))
	hl.dispatch(hl.dsp.cursor.move({ x = x, y = y }))
end

-- First event in a quiet period arms a oneshot timer; events that arrive while
-- armed are ignored. The jiggle fires once at the end of the burst.
local function schedule_jiggle()
	if armed then
		return
	end
	armed = true
	hl.timer(function()
		armed = false
		jiggle()
	end, { timeout = COALESCE_MS, type = "oneshot" })
end

-- Events that can stale pointer focus.
hl.on("workspace.active", function()
	schedule_jiggle()
end)
hl.on("workspace.move_to_monitor", function()
	schedule_jiggle()
end)
hl.on("monitor.focused", function()
	schedule_jiggle()
end)
-- window.active only fires on a real focus change (not on title/class refresh
-- of the already-active window), so no address-dedup is needed here. It also
-- covers special-workspace toggles (which move focus).
hl.on("window.active", function()
	schedule_jiggle()
end)
