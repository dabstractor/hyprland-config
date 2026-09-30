---@module 'hl'

-- ThinkPad T570: muxless Optimus. The eDP panel is wired to the Intel HD 620
-- iGPU (00:02.0 -> /dev/dri/by-path/pci-0000:00:02.0-card); the 940MX dGPU
-- (02:00.0) has no display scanout here and is only for PRIME render offload
-- (`prime-run <app>`).
--
-- Pin the compositor to the Intel iGPU explicitly. With nvidia-drm loaded
-- (modeset=1) the dGPU also registers a DRM node but has no connectors on this
-- muxless panel, so letting Aquamarine auto-pick can grab the wrong device.
-- (Desktop branch pins pci-0000:01:00.0-card instead — keep these per-host.)
-- AQ_DRM_DEVICES is ':'-separated, but the by-path symlink itself contains
-- ':' (pci-0000:00:02.0-card), so it MUST be resolved to the plain /dev/dri/cardN
-- first -- otherwise Aquamarine splits the path on the colons and reports
-- "no gpus to use". (Desktop branch resolves the RTX symlink the same way.)
local igpu = "/dev/dri/card1"
do
	local p = io.popen("readlink -f /dev/dri/by-path/pci-0000:00:02.0-card")
	if p then
		local r = p:read("*l")
		p:close()
		if r and r ~= "" then igpu = r end
	end
end
hl.env("AQ_DRM_DEVICES", igpu)

-- https://wiki.hyprland.org/Configuring/Environment-variables/

-- Keep these OFF globally: setting them would route every GL/VAAPI client onto
-- the dGPU (a PRIME copy that wastes power). For per-app offload, `prime-run`
-- sets these for that one process only.
-- env = LIBVA_DRIVER_NAME,nvidia
-- env = __GLX_VENDOR_LIBRARY_NAME,nvidia

hl.config({
	debug = {
		-- RUN-7I (2026-09-22, sanctioned): was `false`. The runtime-dir
		-- hyprland.log (DEBUG verbosity) grew to 3.3 GB and filled the
		-- 3.2 GB /run/user/1000 tmpfs at 07:04:54 -> ENOSPC broke every
		-- runtime-dir write in the session (wayle panel modules included;
		-- evidence: wayle-config repo docs/design/evidence/run7i-tooltips/).
		-- stdout logs stay ON (journald is size-bounded on /var, not tmpfs).
		-- Rollback: env.lua.bak-7i-enospc (next to this file).
		disable_logs = true,
		enable_stdout_logs = true,
		-- damage_tracking left at default (2) — that NVIDIA workaround only
		-- applies when the compositor itself renders on NVIDIA, which it does
		-- not on this host (Intel iGPU does).
	},
})

----------------------------------------------------------------------
-- Session PATH: this host's Hyprland is launched by /usr/bin/start-hyprland
-- (compiled launcher, no login-shell PATH), so the session only inherited
-- /usr/local/bin:/usr/bin:/var/lib/snapd/snap/bin. Binaries installed under
-- ~/.cargo/bin (hyprscratch) and ~/.local/bin (whisparr-purge, user scripts)
-- were invisible to hl.exec_cmd — every scratchpad bind died silently with
-- "sh: hyprscratch: command not found". Prepend them for the whole session.
-- (Root-caused 2026-09-19; full evidence: /tmp/hyprscratch-investigation.md)
----------------------------------------------------------------------
do
	local home = os.getenv("HOME")
	local old = os.getenv("PATH") or ""
	-- Guard: hl.env applies on every reload and os.getenv() sees the previously
	-- applied value — skip if already prepended so PATH doesn't grow per reload.
	if not old:find(home .. "/.cargo/bin", 1, true) then
		hl.env("PATH", home .. "/.cargo/bin:" .. home .. "/.local/bin:" .. old)
	end
end
