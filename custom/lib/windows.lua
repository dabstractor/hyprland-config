-- Window-level helpers for the custom config. Pure logic; binds stay in
-- custom/keybinds.lua. (Replaced custom/scripts/tiledorfloating.sh, which
-- relied on the now-broken `hyprctl dispatch <name> <params>` form.)
local M = {}


-- The locked terminal scratchpad is launched with --title "terminal"; it is
-- immune to move/resize. Match the stable initialTitle, not the live title
-- (which is now dynamic: "terminal - <app>", driven by tmux set-titles).
function M.is_locked_terminal(win)
	return win ~= nil and win.initial_title == "terminal"
end

-- Resize active window by a relative delta; skip the locked terminal.
-- Also clamps against sub-zero sizes (Hyprland doesn't guard against
-- resizeactive driving a window below 0 px).
function M.resize_if_ok(dx, dy)
	local w = hl.get_active_window()
	if M.is_locked_terminal(w) then
		return
	end
	if w ~= nil then
		local cur_x, cur_y = w.size.x, w.size.y
		if dx < 0 and cur_x + dx < 0 then
			dx = -cur_x
		end
		if dy < 0 and cur_y + dy < 0 then
			dy = -cur_y
		end
	end
	hl.dispatch(hl.dsp.window.resize({ x = dx, y = dy, relative = true }))
end

-- Move the active (floating) window by a relative delta; skip the locked
-- terminal. No-op on tiled windows, matching old `moveactive` behavior.
function M.move_if_ok(dx, dy)
	local w = hl.get_active_window()
	if M.is_locked_terminal(w) then
		return
	end
	hl.dispatch(hl.dsp.window.move({ x = dx, y = dy, relative = true }))
end

-- Floating -> move by delta; Tiled -> focus in a direction. Skip locked terminal.
-- (Was: tiledorfloating.sh "moveactive Dx Dy" "movefocus <dir>".)
function M.move_or_focus(dx, dy, direction)
	local w = hl.get_active_window()
	if M.is_locked_terminal(w) then
		return
	end
	if w and w.floating then
		hl.dispatch(hl.dsp.window.move({ x = dx, y = dy, relative = true }))
	else
		hl.dispatch(hl.dsp.focus({ direction = direction }))
	end
end

-- Cycle windows (fullscreen-aware). If the window we're leaving is fullscreen
-- (or maximized), the window we land on inherits the exact same state
-- (internal + client values are replicated, so real fullscreen, maximized and
-- client-only variants all carry over). On the same workspace Hyprland
-- auto-unfullscreens the old window as soon as the new one takes exclusive
-- fullscreen; windows on other workspaces keep their own state. Uses
-- action="set" (not toggle) so cycling into an already-fullscreen window or
-- landing back on the same window is a no-op instead of dropping you out of
-- fullscreen.
function M.cycle_fs_aware(next_)
	local prev = hl.get_active_window()
	if prev ~= nil and (prev.fullscreen ~= 0 or prev.fullscreen_client ~= 0) then
		local fs, fsc = prev.fullscreen, prev.fullscreen_client
		hl.dispatch(hl.dsp.window.cycle_next({ next = next_ }))
		local now = hl.get_active_window()
		if now ~= nil then
			hl.dispatch(hl.dsp.window.fullscreen_state({
				internal = fs,
				client = fsc,
				action = "set",
				window = "address:" .. now.address,
			}))
		end
	else
		hl.dispatch(hl.dsp.window.cycle_next({ next = next_ }))
	end
end

----------------------------------------------------------------------
-- Cursor zoom (screen magnifier)
----------------------------------------------------------------------

-- zoom_rigid = false so the magnified region tracks the cursor. Mirrors the
-- zoomfunction local to hyprland/keybinds.lua (end4 default SUPER+-/= zoom
-- binds were reclaimed there for resize).
function M.zoomfunction(value)
	local zoomvalue = hl.get_config("cursor:zoom_factor")
	if (zoomvalue + value) > 3.0 then
		hl.config({ cursor = { zoom_factor = 3.0 } })
	elseif (zoomvalue + value) < 1.0 then
		hl.config({ cursor = { zoom_factor = 1.0 } })
	else
		hl.config({ cursor = { zoom_factor = zoomvalue + value } })
	end
end

return M
