-- Scratchpad keybindings. Scratchpads are defined in ~/.config/hypr/hyprscratch.conf.
-- These binds just toggle them. (hyprscratch is an external program, so its config
-- stays in .conf; only these Hyprland binds are Lua.)

-- After toggling the terminal scratchpad, mirror its visibility onto the
-- term-focus-guard rule (a NAMED rule defined globally in custom/rules.lua):
-- guard ON while the terminal is visible (new windows don't steal focus),
-- OFF when hidden (lone windows focus normally). Replaces the dead
-- scripts/term-focus-guard.sh + custom/term-focus-guard.conf round-trip.
local function sync_term_focus_guard()
	if not term_focus_guard then
		return
	end
	local visible = false
	for _, w in ipairs(hl.get_windows()) do
		if w.title == "terminal" and w.mapped and w.workspace and not w.workspace.special and w.workspace.id > 0 then
			visible = true
			break
		end
	end
	term_focus_guard:set_enabled(visible)
end

-- Terminal
hl.bind("ALT + Space", function()
	hl.exec_cmd("hyprscratch toggle terminal")
	-- hyprscratch toggle is async; re-check visibility shortly after it settles.
	hl.timer(sync_term_focus_guard, { timeout = 150, type = "oneshot" })
end)

-- System monitor
hl.bind("SUPER + b", hl.dsp.exec_cmd("hyprscratch toggle btop"))

-- Calculator
hl.bind("ALT + SUPER + C", hl.dsp.exec_cmd("hyprscratch toggle Calculator"))
hl.bind("XF86Calculator", hl.dsp.exec_cmd("hyprscratch toggle Calculator"))

-- Collaboration tools
hl.bind("SUPER + U", hl.dsp.exec_cmd("hyprscratch toggle ClickUp"))
hl.bind("SUPER + ALT + F", hl.dsp.exec_cmd("hyprscratch toggle Figma"))
hl.bind("ALT + SUPER + M", hl.dsp.exec_cmd("hyprscratch toggle Signal"))
hl.bind("SUPER + M", hl.dsp.exec_cmd("hyprscratch toggle Mattermost"))
hl.bind("ALT + SUPER + U", hl.dsp.exec_cmd("hyprscratch toggle Docmost"))
hl.bind("SUPER + V", hl.dsp.exec_cmd("hyprscratch toggle Jitsi_Meet"))
hl.bind("SUPER + Y", hl.dsp.exec_cmd("hyprscratch toggle YouTube_Music"))
hl.bind("SUPER + I", hl.dsp.exec_cmd("hyprscratch toggle Zoho_Mail"))

-- AI Studio
hl.bind("SUPER + A", hl.dsp.exec_cmd("hyprscratch toggle AI_Studio_Profile_0"))
hl.bind("ALT + SUPER + A", hl.dsp.exec_cmd("hyprscratch toggle AI_Studio_Profile_1"))

-- Claude
hl.bind("SUPER + C", hl.dsp.exec_cmd("hyprscratch toggle Claude"))

-- Obsidian
hl.bind("SUPER + Semicolon", hl.dsp.exec_cmd("hyprscratch toggle neovide-obsidian-vault"))
hl.bind("ALT + SUPER + Semicolon", hl.dsp.exec_cmd("hyprscratch toggle obsidian"))

-- Clipboard history
hl.bind("SUPER + Return", hl.dsp.exec_cmd("hyprscratch toggle cliphist"))
