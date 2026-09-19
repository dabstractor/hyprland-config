----------------------------------------------------------------------
-- Capture: screenshots, OCR, screen-translate, recording.
-- Quickshell-free. Required (via pcall) from the end of custom/keybinds.lua.
--
-- Engine:
--   * hyprshot — battle-tested wrapper around grim + slurp + wl-clipboard.
--     Modes: region / window (active) / output (active monitor).
--     Clipboard-only variants are --silent; file variants save to SHOT_DIR
--     AND copy to the clipboard (hyprshot's default behavior) and send a
--     notification (needs a notification daemon: qs for now, dunst/mako later).
--   * wf-recorder — toggle-style screen recording via record_toggle.sh.
--   * tesseract — OCR (screenshot_ocr.sh) and translate (screenshot_translate.sh).
--
-- Keymap (Print = capture; hold CTRL = also save to file):
--   SUPER+SHIFT+S      region          -> clipboard
--   SHIFT+Print        region          -> /tmp/screenshots + clipboard
--   ALT+Print          active window   -> clipboard
--   CTRL+ALT+Print     active window   -> /tmp/screenshots + clipboard
--   Print              active monitor  -> clipboard
--   CTRL+Print         active monitor  -> /tmp/screenshots + clipboard
--   SUPER+SHIFT+X      region -> OCR -> clipboard
--   SUPER+SHIFT+A      region -> Google Lens (snip_to_search.sh)
--   SUPER+SHIFT+T      region -> OCR -> translate -> clipboard
--   SUPER+SHIFT+R      toggle region recording (wf-recorder)
--   CTRL+ALT+R         toggle fullscreen recording
--   SUPER+SHIFT+ALT+R  toggle fullscreen recording with audio
----------------------------------------------------------------------

local hyprScripts = "$HOME/.config/hypr/hyprland/scripts"

-- File-saving captures land here (hyprshot creates it on demand).
local SHOT_DIR = "/tmp/screenshots"

--## Region
hl.bind(
	"SUPER + SHIFT + S",
	hl.dsp.exec_cmd("hyprshot --mode region --freeze --clipboard-only --silent"),
	{ description = "Capture: Region >> clipboard" }
)
hl.bind(
	"SHIFT + Print",
	hl.dsp.exec_cmd("hyprshot --mode region --freeze --output-folder " .. SHOT_DIR),
	{ description = "Capture: Region >> file + clipboard" }
)

--## Active window
hl.bind(
	"ALT + Print",
	hl.dsp.exec_cmd("hyprshot --mode window --mode active --clipboard-only --silent"),
	{ description = "Capture: Active window >> clipboard" }
)
hl.bind(
	"CTRL + ALT + Print",
	hl.dsp.exec_cmd("hyprshot --mode window --mode active --output-folder " .. SHOT_DIR),
	{ description = "Capture: Active window >> file + clipboard" }
)

--## Full screen (active monitor)
hl.bind(
	"Print",
	hl.dsp.exec_cmd("hyprshot --mode output --mode active --clipboard-only --silent"),
	{ description = "Capture: Screen >> clipboard" }
)
hl.bind(
	"CTRL + Print",
	hl.dsp.exec_cmd("hyprshot --mode output --mode active --output-folder " .. SHOT_DIR),
	{ description = "Capture: Screen >> file + clipboard" }
)

--## OCR / Lens / Translate
hl.bind("SUPER + SHIFT + X", hl.dsp.exec_cmd(hyprScripts .. "/screenshot_ocr.sh"), {
	description = "Capture: Region >> OCR >> clipboard",
})
hl.bind("SUPER + SHIFT + A", hl.dsp.exec_cmd(hyprScripts .. "/snip_to_search.sh"), {
	description = "Capture: Region >> Google Lens",
})
hl.bind("SUPER + SHIFT + T", hl.dsp.exec_cmd(hyprScripts .. "/screenshot_translate.sh"), {
	description = "Capture: Region >> OCR >> translate >> clipboard",
})

--## Recording (toggle with the same key)
hl.bind("SUPER + SHIFT + R", hl.dsp.exec_cmd(hyprScripts .. "/record_toggle.sh"), {
	description = "Record: Toggle region recording",
})
hl.bind("CTRL + ALT + R", hl.dsp.exec_cmd(hyprScripts .. "/record_toggle.sh --fullscreen"), {
	description = "Record: Toggle fullscreen recording",
})
hl.bind(
	"SUPER + SHIFT + ALT + R",
	hl.dsp.exec_cmd(hyprScripts .. "/record_toggle.sh --fullscreen --sound"),
	{ description = "Record: Toggle fullscreen recording (with audio)" }
)
