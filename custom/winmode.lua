-- Window-leader modes for Hyprland, tmux-prefix / neovim-<C-w> style. Four
-- dedicated leaders, each entering a mode where the BARE encoders do that one
-- action (no in-mode modifier juggling):
--
--     SUPER + W            -> RESIZE   (encoder up/down = vertical, left/right = horizontal)
--     ALT + SUPER + W      -> SWAP     (tiled: swap neighbor; floating: move)
--     CTRL + SUPER + W     -> FOCUS    (focus window up/down/left/right)
--     SHIFT + SUPER + W    -> CARRY    (move window across workspaces: up/right = next, down/left = prev)
--
-- In RESIZE mode , / . also resize horizontally (keyboard). Exit any mode with
-- Escape, by re-pressing the same leader, or after MODE_IDLE_MS of inactivity.
--
-- WHY A LUA FLAG, NOT A SUBMAP: Hyprland 0.55 has a bug where mouse/wheel binds
-- do not fire inside a non-default submap (hyprwm/Hyprland #14917, #15058,
-- #15068), and runtime hl.bind registers but never fires (#13993). The wheels
-- therefore MUST live in the DEFAULT submap, so we emulate the "mode" with a
-- Lua state variable instead of a real submap.
--
-- TRADEOFF (non_consuming): the wheel binds pass the event to the app as well as
-- firing. That keeps normal scrolling working when no mode is active, but while
-- a mode is active the wheel event ALSO reaches the app, so content may scroll
-- slightly during an action (usually unnoticeable on tiled windows).
--
-- ISOLATION: required from custom/keybinds.lua via pcall, so a Lua error here
-- can never take the rest of the custom keybinds down.

local STEP = 40 -- px per encoder tick for RESIZE; matches SUPER+ALT(+SHIFT)+wheel binds in custom/keybinds.lua
local MOVE_STEP = 40 -- px per encoder tick for floating MOVE (swap mode)
local MODE_IDLE_MS = 2000 -- auto-exit a mode after this much inactivity (mirrors neovim's resize_mode_timer; tunable)
local CARRY_SETTLE_MS = 30 -- debounce window for workspace-carry (movetoworkspace serializes on rapid ticks)

-- The locked terminal scratchpad (launched with --title "terminal") is immune
-- to move/resize. Same guard the main keybinds file uses.
local function is_locked_terminal(win)
	return win ~= nil and (win.initial_title == "terminal" or win.title == "terminal")
end

local function resize_if_ok(dx, dy)
	local w = hl.get_active_window()
	if is_locked_terminal(w) then
		return
	end
	hl.dispatch(hl.dsp.window.resize({ x = dx, y = dy, relative = true }))
end

-- Floating -> move by delta; Tiled -> swap in a direction (swapwindow preserves
-- the split ratio, unlike movewindow). Skip the locked terminal.
local function move_or_swap(dx, dy, direction)
	local w = hl.get_active_window()
	if is_locked_terminal(w) then
		return
	end
	if w and w.floating then
		hl.dispatch(hl.dsp.window.move({ x = dx, y = dy, relative = true }))
	else
		hl.dispatch(hl.dsp.window.swap({ direction = direction }))
	end
end

-- Debounced workspace carry: accumulate signed ticks while the encoder spins,
-- then fire ONE movetoworkspace ±N shortly after it settles. (Copied from the
-- SUPER+SHIFT+wheel carry in custom/keybinds.lua; movetoworkspace is a heavy,
-- non-interruptible op, so per-tick dispatch visibly "loads" every workspace.)
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

local function carry_window(delta)
	carry_accumulator = carry_accumulator + delta
	if carry_timer then
		carry_timer:set_enabled(false)
	end
	carry_timer = hl.timer(carry_flush, { timeout = CARRY_SETTLE_MS, type = "oneshot" })
end

-- ---- mode state + idle auto-exit timer ----
local current_mode = "" -- "", "resize", "swap", "focus", "carry"
local idle_timer = nil

local function disarm_idle()
	if idle_timer then
		idle_timer:set_enabled(false)
		idle_timer = nil
	end
end

local function rearm_idle()
	disarm_idle()
	idle_timer = hl.timer(function()
		current_mode = ""
	end, { timeout = MODE_IDLE_MS, type = "oneshot" })
end

local function exit_mode()
	disarm_idle()
	current_mode = ""
end

-- Pressing a leader toggles its mode: re-pressing the same leader exits;
-- pressing a different leader switches to it.
local function set_mode(name)
	if current_mode == name then
		exit_mode()
	else
		current_mode = name
		rearm_idle()
	end
end

-- Dispatch one wheel event ("up"/"down"/"left"/"right") based on the active
-- mode. Pure no-op (and, via non_consuming, passed through) when no mode is on.
local function handle_wheel(which)
	if current_mode == "" then
		return
	end
	if current_mode == "resize" then
		if which == "up" then
			resize_if_ok(0, STEP)
		elseif which == "down" then
			resize_if_ok(0, -STEP)
		elseif which == "right" then
			resize_if_ok(STEP, 0)
		elseif which == "left" then
			resize_if_ok(-STEP, 0)
		end
	elseif current_mode == "swap" then
		if which == "up" then
			move_or_swap(0, -MOVE_STEP, "up")
		elseif which == "down" then
			move_or_swap(0, MOVE_STEP, "down")
		elseif which == "left" then
			move_or_swap(-MOVE_STEP, 0, "left")
		elseif which == "right" then
			move_or_swap(MOVE_STEP, 0, "right")
		end
	elseif current_mode == "focus" then
		hl.dispatch(hl.dsp.focus({ direction = which }))
	elseif current_mode == "carry" then
		if which == "up" or which == "right" then
			carry_window(1)
		elseif which == "down" or which == "left" then
			carry_window(-1)
		end
	end
	rearm_idle()
end

-- ---- the four leaders (default submap) ----
hl.bind("SUPER + W", function()
	set_mode("resize")
end, { description = "Winmode: resize leader" })
hl.bind("ALT + SUPER + W", function()
	set_mode("swap")
end, { description = "Winmode: swap/move leader" })
hl.bind("CTRL + SUPER + W", function()
	set_mode("focus")
end, { description = "Winmode: focus leader" })
hl.bind("SHIFT + SUPER + W", function()
	set_mode("carry")
end, { description = "Winmode: workspace-carry leader" })

-- ---- bare encoders (non_consuming so normal scroll works when no mode is on) ----
hl.bind("mouse_up", function()
	handle_wheel("up")
end, { non_consuming = true })
hl.bind("mouse_down", function()
	handle_wheel("down")
end, { non_consuming = true })
hl.bind("mouse_left", function()
	handle_wheel("left")
end, { non_consuming = true })
hl.bind("mouse_right", function()
	handle_wheel("right")
end, { non_consuming = true })

-- ---- keyboard resize (resize mode only) ----
hl.bind("comma", function()
	if current_mode == "resize" then
		resize_if_ok(-STEP, 0)
		rearm_idle()
	end
end, { repeating = true, non_consuming = true })
hl.bind("period", function()
	if current_mode == "resize" then
		resize_if_ok(STEP, 0)
		rearm_idle()
	end
end, { repeating = true, non_consuming = true })

-- ---- Escape exits any mode (non_consuming so normal Escape still reaches apps) ----
hl.bind("escape", function()
	if current_mode ~= "" then
		exit_mode()
	end
end, { non_consuming = true })