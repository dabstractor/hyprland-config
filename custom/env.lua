---@module 'hl'

-- VNC session identity: true ONLY inside the ghost-desktop (thin-client)
-- session. Its launcher (ghost-desktop-run) gives it a private
-- XDG_RUNTIME_DIR (/run/user/<uid>/ghd); a physical SDDM/uwsm login always
-- gets the default /run/user/<uid> from PAM. Unlike WLR_BACKENDS or
-- WAYLAND_DISPLAY, this cannot leak between sessions (the shared systemd
-- user-manager env carries no XDG_RUNTIME_DIR), so VNC-only code gated on
-- it can never execute in a physical login. It previously DID via leaked
-- WLR_BACKENDS=headless, and the resulting WAYLAND-1 monitor rule broke
-- display restoration after a VT switch (atomic restore commit rejected
-- with EINVAL -> black screen with only a hardware cursor).
IS_VNC_SESSION = (os.getenv("XDG_RUNTIME_DIR") or ""):match("/ghd$") ~= nil

-- GPU selection: the Intel iGPU (00:02.0) is passed through to the qmk-win VM
-- (vfio-pci), so it's gone from host DRM and the RTX 3080 Ti (01:00.0) is the
-- only host GPU -> currently /dev/dri/card1 (it was card2 while the iGPU was
-- card1). The card number can shift if you revert passthrough or add/remove a
-- GPU, so resolve the stable by-path symlink at config-load time instead of
-- hard-coding it. (Check `ls -l /dev/dri/by-path/` if Hyprland won't start;
-- with a single host GPU you may also just delete this block and let Hyprland
-- auto-pick.)
-- PHYSICAL SESSIONS ONLY (IS_VNC_SESSION gate). In the nested/VNC session
-- this MUST NOT run: it would setenv AQ_DRM_DEVICES=<RTX> over the
-- launcher's iGPU pin INSIDE the compositor process (config loads before
-- backend creation; /proc/environ audits cannot see it). Combined with the
-- libseat seat-piggyback (any active seat0 session of the user grants a
-- seat to the nested Hyprland too), that turned the nested session into a
-- DRM compositor on the RTX -> Mesa-only EGL abort -> black-void VNC. The
-- shim's AQ_NO_DRM_BACKEND guard is the hard fix; this gate is
-- defense-in-depth so the nested tree never carries an RTX pin at all.
if not IS_VNC_SESSION then
	local rtx_link = "/dev/dri/by-path/pci-0000:01:00.0-card"
	local rtx_card
	do
		local pipe = io.popen("readlink -f " .. rtx_link)
		if pipe then
			rtx_card = pipe:read("*l")
			pipe:close()
		end
	end
	-- Fall back to the last-known card if readlink fails or the symlink is gone.
	rtx_card = (rtx_card and rtx_card ~= "") and rtx_card or "/dev/dri/card1"
	hl.env("AQ_DRM_DEVICES", rtx_card)
end

-- Moved out of hyprland/execs.lua (end4 dir -- overwritten on update):
-- `qs -c $qsConfig` fails in the VNC session because the ghost-desktop unit
-- env has no qsConfig. This file is required BEFORE hyprland/execs.lua and
-- hl.env() setenvs at parse time, so the default is in place before the
-- end4 start-handler's spawned command expands $qsConfig.
hl.env("qsConfig", os.getenv("qsConfig") or "ii")

-- Second piece that lived in hyprland/execs.lua: in the VNC session the
-- end4 start-handler must NOT be allowed to (a) run
-- `dbus-update-activation-environment --all` (exports the private ghd
-- runtime dir, patched-aquamarine LD_LIBRARY_PATH, WLR_*/EGL overrides,
-- PULSE_SERVER and the unit's 3-entry PATH into the SHARED activation
-- env) nor its `--systemd WAYLAND_DISPLAY ...` follow-up (exports the
-- private socket name), and (b) start per-user singletons a physical
-- session already owns (gnome-keyring, hypridle, easyeffects,
-- wl-paste --watch: a second watcher cross-contaminates clipboards).
-- Lua has no "unbind" for exec_cmds, so this is the unbinds-file
-- equivalent for autostarts: prepend a shim dir to PATH for this session
-- only (hl.env is parse-time, so it applies to every command the end4
-- handler spawns). Each shim defers to custom/scripts/nested-solo.sh --
-- no-op when a physical session owns the singleton, exec the real binary
-- otherwise. Physical sessions never get the PATH entry at all.
if IS_VNC_SESSION then
	local shims = os.getenv("HOME") .. "/.config/hypr/custom/scripts/vnc-shims"
	hl.env("PATH", shims .. ":" .. (os.getenv("PATH") or ""))
end

-- https://wiki.hyprland.org/Configuring/Environment-variables/

-- env = LIBVA_DRIVER_NAME,nvidia
-- env = __GLX_VENDOR_LIBRARY_NAME, nvidia

hl.config({
	debug = {
		disable_logs = false,
		-- Mode 2 (default) = per-pixel damage tracking. On NVIDIA it produces
		-- false negatives: a translucent/blurred window over a fast-updating
		-- (hardware-accelerated) surface stops getting repainted and shows
		-- stale/corrupted contents until a full repaint (e.g. workspace switch).
		-- Mode 1 = repaint the whole monitor whenever anything is damaged;
		-- trades a little GPU for correctness. (0 = full repaint every frame.)
		damage_tracking = 1,
	},
})
