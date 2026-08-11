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
		disable_logs = false,
		enable_stdout_logs = true,
		-- damage_tracking left at default (2) — that NVIDIA workaround only
		-- applies when the compositor itself renders on NVIDIA, which it does
		-- not on this host (Intel iGPU does).
	},
})
