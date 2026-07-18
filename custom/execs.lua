-- Autostart. Put former exec-once commands inside the hyprland.start handler
-- (runs once per session); top-level hl.exec_cmd would run on every reload.

-- Native pointer-focus listener (replaces custom/scripts/pointer-focus-listener.py
-- + refresh-pointer-focus.sh). Registered at parse time via top-level hl.on.
pcall(require, "custom.pointer-focus")

hl.on("hyprland.start", function()
	hl.exec_cmd("hyprscratch init clean spotless")
	hl.exec_cmd("~/.config/hypr/scripts/autostart.sh")
	hl.exec_cmd("~/.config/hypr/scripts/clipboard-sync.sh")
	hl.exec_cmd("kanshi")
	hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
	-- Portal startup-race fix: xdg-desktop-portal-hyprland is sometimes D-Bus
	-- activated before WAYLAND_DISPLAY reaches the dbus/systemd activation env,
	-- so it fails to connect to the compositor, retries 3x, hits systemd's
	-- start-rate-limit and stays dead for the whole session -> no screen share.
	-- Now that Hyprland + the env are up, clear any failed state and restart the
	-- portal stack so the Hyprland backend connects cleanly.
	hl.exec_cmd("sleep 2; systemctl --user reset-failed xdg-desktop-portal-hyprland 2>/dev/null; systemctl --user restart xdg-desktop-portal-hyprland xdg-desktop-portal")
	hl.exec_cmd("mkdir -p /run/user/1000/hyprpm")
	hl.exec_cmd("syncthing")
	hl.exec_cmd("udiskie")
	hl.dispatch(hl.dsp.focus({ workspace = 15 }))
	hl.exec_cmd("vicinae server")
	-- Route agent-browser's browser windows to a dedicated workspace band.
	-- Identifies them by process ancestry; personal Chrome is left untouched.
	-- Tunable via env: AB_WORKSPACE, AB_DEBUG, AB_DRY_RUN.
	hl.exec_cmd("~/.config/hypr/custom/scripts/agent-browser-workspace.py")
end)
