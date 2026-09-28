-- Autostart. Put former exec-once commands inside the hyprland.start handler
-- (runs once per session); top-level hl.exec_cmd would run on every reload.

-- Native pointer-focus listener (replaces custom/scripts/pointer-focus-listener.py
-- + refresh-pointer-focus.sh). Registered at parse time via top-level hl.on.
pcall(require, "custom.pointer-focus")


-- Activity-following singletons: ANY activity in THIS session re-homes
-- the user-global services (hyprscratch, launcher spawn routing) here via
-- session-steal — focus changes of any kind (click/hover/cycle/alt-tab),
-- workspace switches, window opens, and every keystroke. Lua-side throttle
-- (>=8s between spawns) keeps the per-keystroke cost at one integer
-- compare; the script itself no-ops (38ms) when this session already owns
-- everything. Works in both the physical and VNC branches (same config);
-- sessions also steal once at start.
local _steal_last = 0
local function _steal()
	local t = os.time()
	if t - _steal_last >= 8 then
		_steal_last = t
		hl.exec_cmd("/home/dustin/.local/bin/session-steal --quiet")
	end
end
hl.on("window.active", function() _steal() end)
hl.on("workspace.active", function() _steal() end)
hl.on("window.open", function() _steal() end)
hl.on("input.keyboard.key", function() _steal() end)

hl.on("hyprland.start", function()
	-- Steal the user-global singletons immediately on session start (the
	-- activity listeners below keep them following whichever session is
	-- being used).
	hl.exec_cmd("/home/dustin/.local/bin/session-steal --quiet")
	-- Coexistence: guard per-user singletons in the VNC session so they
	-- only start when no physical session already owns them.
	local solo = ""
	if IS_VNC_SESSION then
		solo = "~/.config/hypr/custom/scripts/nested-solo.sh && "
	end

	hl.exec_cmd("hyprscratch init clean spotless")
	hl.exec_cmd("~/.config/hypr/scripts/autostart.sh")
	hl.exec_cmd(solo .. "~/.config/hypr/scripts/clipboard-sync.sh")
	hl.exec_cmd("kanshi")
	if IS_VNC_SESSION then
		-- VNC/headless instance: explicit locator list only (see
		-- hyprland/execs.lua for why --all is forbidden here).
		hl.exec_cmd(
			"env WAYLAND_DISPLAY=wayland-ghd dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE PATH"
		)
	else
		hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
	end
	-- Portal startup-race fix: xdg-desktop-portal-hyprland is sometimes D-Bus
	-- activated before WAYLAND_DISPLAY reaches the dbus/systemd activation env,
	-- so it fails to connect to the compositor, retries 3x, hits systemd's
	-- start-rate-limit and stays dead for the whole session -> no screen share.
	-- Now that Hyprland + the env are up, clear any failed state and restart the
	-- portal stack so the Hyprland backend connects cleanly.
	hl.exec_cmd(
		solo .. "sleep 2; systemctl --user reset-failed xdg-desktop-portal-hyprland 2>/dev/null; systemctl --user restart xdg-desktop-portal-hyprland xdg-desktop-portal"
	)
	hl.exec_cmd("mkdir -p /run/user/1000/hyprpm")
	hl.exec_cmd(solo .. "syncthing")
	hl.exec_cmd(solo .. "udiskie")
	hl.dispatch(hl.dsp.focus({ workspace = 15 }))
	hl.exec_cmd(solo .. "vicinae server")
	-- Route agent-browser's browser windows to a dedicated workspace band.
	-- Identifies them by process ancestry; personal Chrome is left untouched.
	-- Tunable via env: AB_WORKSPACE, AB_DEBUG, AB_DRY_RUN.
	hl.exec_cmd("~/.config/hypr/custom/scripts/agent-browser-workspace.py")
end)
