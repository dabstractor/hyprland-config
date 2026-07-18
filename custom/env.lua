---@module 'hl'

-- https://wiki.hyprland.org/Configuring/Environment-variables/

-- env = LIBVA_DRIVER_NAME,nvidia

-- env = __GLX_VENDOR_LIBRARY_NAME, nvidia

-- GPU selection: the Intel iGPU (00:02.0) is passed through to the qmk-win VM
-- (vfio-pci), so it's gone from host DRM and the RTX 3080 Ti (01:00.0) is the
-- only host GPU -> /dev/dri/card1 (it was card2 while the iGPU was card1).
-- If you revert passthrough or add/remove a GPU, the RTX's card number can shift;
-- check `ls -l /dev/dri/by-path/` and update this if Hyprland won't start.
-- (With a single host GPU you may also just delete this line and let Hyprland
--  auto-pick.)
--hl.env("AQ_DRM_DEVICES", "/dev/dri/card0")

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
