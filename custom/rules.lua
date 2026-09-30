-- Custom window / layer / workspace rules.
-- Reconstructed by hand from the pre-migration rules.conf (the hyprconf2lua
-- output had placed every effect into match.class, which is wrong).
-- Window/layer rules: https://wiki.hyprland.org/Configuring/Window-Rules/

-- Jitsi screen-share indicator — shove offscreen (move needs both x and y).
hl.window_rule({
	match = { title = "^(jitsi\\.mulletware\\.io is sharing your screen.)$" },
	move = { "-100", "-100" },
})

-- Floating popup window at a default size.
hl.window_rule({
	match = { title = "^(Untitled - Google Chrome)$" },
	float = true,
	size = { "1000", "600" },
})

-- DevTools.
hl.window_rule({ match = { title = "^DevTools" }, tile = true })

-- Calculator: float at a sane size in the bottom-right corner -- 2% off the
-- right edge, 5% off the bottom. gnome-calculator's class is org.gnome.Calculator
-- and it ignores size rules (it constrains to a ~360px min width), so the move
-- expression uses the window-rule position vars (window_w/h, monitor_w/h -- all
-- logical, evaluated by muParser) to adapt to whatever size it actually takes.
-- The old rule omitted `float` (so size/move were ignored on the tiled window)
-- and used the brittle `100%-400px` form, which never parsed -- landing it
-- centered. No show-time move is needed; the position set here persists across
-- hyprscratch show/hide (which only re-applies float+size, keeping top-left).
hl.window_rule({
	match = { title = "^(Calculator)$" },
	float = true,
	size = { "400", "600" },
	move = { "monitor_w - window_w - monitor_w * 0.02", "monitor_h - window_h - monitor_h * 0.05" },
})

-- ClickUp (title match).
hl.window_rule({
	match = { title = "^ClickUp$" },
	float = true,
	size = { "49%", "98%" },
	move = { "0.4%", "1%" },
})

-- Mattermost.
hl.window_rule({
	match = { title = "^Mattermost$" },
	float = true,
	size = { "80%", "80%" },
	center = true,
})

-- Jitsi Meet.
hl.window_rule({
	match = { title = "^Jitsi Meet" },
	float = true,
	size = { "100%", "100%" },
	center = true,
})

-- Zoho Mail.
hl.window_rule({
	match = { title = "^Zoho Mail$" },
	float = true,
	size = { "60%", "80%" },
	center = true,
})

-- Claude.
hl.window_rule({
	match = { title = "^Claude" },
	float = true,
	size = { "80%", "99.5%" },
	move = { "0%", "-1.2%" },
})

-- Google AI Studio.
hl.window_rule({
	match = { title = "^Google AI Studio" },
	float = true,
	size = { "80%", "99.5%" },
	move = { "0%", "-1.2%" },
})

-- Docmost.
hl.window_rule({
	match = { title = "^Docmost" },
	float = true,
	size = { "80%", "99.5%" },
	move = { "0%", "-1.2%" },
})

-- YouTube Music.
hl.window_rule({
	match = { title = "^YouTube Music" },
	float = true,
	size = { "40%", "60%" },
	center = true,
})

-- ClickUp (class match).
hl.window_rule({
	match = { class = "^ClickUp$" },
	float = true,
	size = { "49%", "98%" },
	move = { "0.4%", "1%" },
})

-- Figma (title match) — centered.
hl.window_rule({
	match = { title = "^Figma$" },
	float = true,
	size = { "3560", "2060" },
	center = true,
})

-- Figma (class match).
hl.window_rule({
	match = { class = "^figma-linux$" },
	float = true,
	size = { "3560", "2060" },
	center = true,
})

-- Steam apps — fullscreen.
hl.window_rule({ match = { class = "^steam_app.*" }, fullscreen = true })
-- Looking Glass client (VM display passthrough) — always true fullscreen.
hl.window_rule({ match = { class = "^looking-glass-client$" }, fullscreen = true })
-- .exe apps — fullscreen.
hl.window_rule({ match = { class = "^.*\\.exe$" }, fullscreen = true })
-- Steam apps (alternate pattern).
hl.window_rule({ match = { class = "^steam.*app.*" }, fullscreen = true })

-- Bitwarden extension.
hl.window_rule({ match = { class = ".*nngceckbapebfimnlniiiahkandclblb.*" }, float = true })
hl.window_rule({ match = { title = "Bitwarden" }, size = { "200", "400" } })

-- pgmodeler.
hl.window_rule({ match = { class = "^pgmodeler$" }, float = true })
hl.window_rule({ match = { title = "^pgModeler  - .*" }, tile = true })

-- swayimg - always open fullscreen.
-- NOTE: the naive static rule `hl.window_rule({ match = { class = "^swayimg$" },
-- fullscreen = true })` does NOT work here. swayimg is Wayland-native and sizes its
-- toplevel to the image AFTER mapping, without itself requesting fullscreen.
-- Hyprland applies the static rule at open, but the client's subsequent
-- configure/commit drops the fullscreen state (verified: a fresh swayimg comes
-- up with fs=0). steam/looking-glass/.exe rules appear to work only because
-- those apps self-request fullscreen at the protocol level; swayimg does not.
-- Dispatching fullscreen from a `window.open` listener (fired after the window
-- is fully initialized) reliably sticks, so we use that instead.
hl.on("window.open", function(w)
	if w ~= nil and w.class == "swayimg" and w.address ~= nil then
		hl.dispatch(hl.dsp.window.fullscreen({
			mode = "fullscreen",
			action = "set",
			window = "address:" .. w.address,
		}))
	end
end)

----------------------------------------------------------------------
-- Terminal focus guard (replaces scripts/term-focus-guard.sh + the dead
-- custom/term-focus-guard.conf fragment, which is no longer sourced in 0.55).
--
-- A static catch-all no_initial_focus rule would also stop the ONLY window on
-- screen from focusing. We want to block focus-theft only WHILE the floating
-- terminal scratchpad is visible, and let lone windows focus normally when it
-- is hidden. So this is a NAMED rule toggled at runtime via :set_enabled().
--
-- `term_focus_guard` is a GLOBAL (no `local`) so custom/hyprscratch.lua can
-- flip it from the Alt+Space terminal toggle. Initial state mirrors the
-- terminal's current visibility (correct across reloads too).
term_focus_guard = hl.window_rule({
	name = "term-focus-guard",
	match = { class = ".*" },
	no_initial_focus = true,
})

do
	local term_visible = false
	for _, w in ipairs(hl.get_windows()) do
		-- Match the stable initialTitle, not the live title (now dynamic: see
		-- custom/hyprscratch.lua). Keeps the guard in the right state across reloads.
		if
			w.initial_title == "terminal"
			and w.mapped
			and w.workspace
			and not w.workspace.special
		then
			term_visible = true
			break
		end
	end
	term_focus_guard:set_enabled(term_visible)
end

----------------------------------------------------------------------
-- Terminal-scratchpad float lock
--
-- hyprscratch only "sees" a scratchpad as shown when its window is floating
-- (get_mode() filters on floating || tiled). If the scratchpad terminal ever
-- gets tiled — e.g. an accidental SUPER+ALT+Space float toggle — every
-- ALT+Space becomes a re-summon and it can never be hidden again
-- (2026-09-19 incident). Self-heal instead of hoping: whenever the
-- scratchpad terminal gains focus or moves between workspaces (hyprscratch's
-- show/hide is a workspace move), re-assert floating. The guarded
-- SUPER+ALT+Space rebind in custom/keybinds.lua is the other half.
-- Escape hatch: delete this block (and the guarded bind) to unlock.
----------------------------------------------------------------------
local function assert_scratchpad_terminal_float(w)
	if w == nil or w.initial_title ~= "terminal" then
		return
	end
	if not w.floating then
		hl.dispatch(hl.dsp.window.float({ action = "set", window = "address:" .. w.address }))
	end
end

hl.on("window.active", function(w)
	-- NB: docs say the second arg is 0/1 but builds send focus-reason enums
	-- (observed 3); don't filter on it — the assert is idempotent.
	assert_scratchpad_terminal_float(w)
end)
hl.on("window.move_to_workspace", function(w)
	assert_scratchpad_terminal_float(w)
end)

-- dlna video picker — ephemeral floating terminal
hl.window_rule({
	match = { title = "^dlna-picker$" },
	float = true,
	size = { "(monitor_w*0.60)", "(monitor_h*0.80)" },
	move = { "(monitor_w*0.20)", "(monitor_h*0.10)" },
})
