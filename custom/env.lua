---@module 'hl'

-- GPU selection: the Intel iGPU (00:02.0) is passed through to the qmk-win VM
-- (vfio-pci), so it's gone from host DRM and the RTX 3080 Ti (01:00.0) is the
-- only host GPU -> currently /dev/dri/card1 (it was card2 while the iGPU was
-- card1). The card number can shift if you revert passthrough or add/remove a
-- GPU, so resolve the stable by-path symlink at config-load time instead of
-- hard-coding it. (Check `ls -l /dev/dri/by-path/` if Hyprland won't start;
-- with a single host GPU you may also just delete this block and let Hyprland
-- auto-pick.)
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
