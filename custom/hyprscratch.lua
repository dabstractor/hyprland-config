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

-- Summon a scratchpad so it grabs focus even while the term-focus-guard is
-- armed. The guard (see custom/rules.lua) is a catch-all `no_initial_focus`
-- rule active while the terminal scratchpad is visible; it suppresses the
-- INITIAL focus of any window that maps while armed. hyprscratch's cold-launch
-- path (`spawn_normal`) relies on that initial focus -- its warm path
-- (`show_normal`) focuses explicitly -- so a freshly-spawned scratchpad maps
-- unfocused, but only while the terminal is open. That is exactly the
-- "only when it's not already running" symptom.
--
-- Fix: briefly disarm the guard around the summon so the new window maps with
-- its normal initial focus, then re-arm it (mirroring terminal visibility) once
-- the window is up. Safe because cold launches already focus fine when the
-- terminal -- and thus the guard -- is hidden; we just recreate that condition
-- for the summon. (The earlier attempt force-focused the window afterwards, but
-- matched on the *current* title, which fzf rewrites inside the cliphist
-- terminal -- so the poll never found it.)
local function summon_focused(title)
	-- Already visible -> this toggle hides/refocuses it; hyprscratch focuses
	-- explicitly there (bypasses no_initial_focus), so leave the guard alone.
	for _, w in ipairs(hl.get_windows()) do
		if (w.initial_title == title or w.initial_class == title)
			and w.mapped and w.workspace and not w.workspace.special and w.workspace.id > 0 then
			return
		end
	end

	-- Disarm the guard so the freshly-mapped window receives initial focus.
	if term_focus_guard then
		term_focus_guard:set_enabled(false)
	end

	-- Re-arm (matching terminal visibility) once the window has mapped, or give
	-- up after ~2s. Match on initial_title/initial_class: those stay stable even
	-- if the app retitles the window later (e.g. fzf inside the cliphist window),
	-- whereas the current title may already have changed by the time we poll.
	local attempts = 0
	local timer
	timer = hl.timer(function()
		attempts = attempts + 1
		local up = false
		for _, w in ipairs(hl.get_windows()) do
			if (w.initial_title == title or w.initial_class == title)
				and w.mapped and w.workspace and not w.workspace.special and w.workspace.id > 0 then
				up = true
				break
			end
		end
		if up or attempts >= 20 then -- ~2s (20 * 100ms)
			if timer then
				timer:set_enabled(false)
			end
			sync_term_focus_guard()
		end
	end, { timeout = 100, type = "repeat" })
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
local function toggle_calculator()
	summon_focused("Calculator")
	hl.exec_cmd("hyprscratch toggle Calculator")
end
hl.bind("ALT + SUPER + C", toggle_calculator)
hl.bind("XF86Calculator", toggle_calculator)

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
hl.bind("SUPER + Return", function()
	summon_focused("cliphist")
	hl.exec_cmd("hyprscratch toggle cliphist")
end)
