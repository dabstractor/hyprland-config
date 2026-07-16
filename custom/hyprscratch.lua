-- Scratchpad keybindings. Scratchpads are defined in ~/.config/hypr/hyprscratch.conf.
-- These binds just toggle them. (hyprscratch is an external program, so its config
-- stays in .conf; only these Hyprland binds are Lua.)
--
-- Focus model: the floating terminal scratchpad is protected by a NAMED no_initial_focus rule ("term-focus-guard", defined in custom/rules.lua) that is ARMED only while the terminal is visible, so ordinary windows opening beneath it don't steal focus. Every OTHER scratchpad must grab focus the moment it opens. toggle_scratchpad() reconciles the two -- see its comment for how. Is the floating terminal scratchpad currently shown on a normal workspace? (hyprscratch parks a hidden scratchpad on a special workspace.) This is also the condition that arms term-focus-guard, so it doubles as the guard's intended state.
local function terminal_visible()
	for _, w in ipairs(hl.get_windows()) do
		if w.title == "terminal" and w.mapped and w.workspace and not w.workspace.special and w.workspace.id > 0 then
			return true
		end
	end
	return false
end

-- After toggling the terminal scratchpad, mirror its visibility onto the
-- term-focus-guard rule: guard ON while the terminal is visible (new windows
-- don't steal focus), OFF when hidden (lone windows focus normally).
local function sync_term_focus_guard()
	if not term_focus_guard then
		return
	end
	term_focus_guard:set_enabled(terminal_visible())
end

-- Is a scratchpad process running AT ALL -- mapped on any workspace, normal OR
-- special? hyprscratch parks hidden scratchpads on a special workspace, so a
-- hidden-but-running app still counts as "running". Only a window that exists
-- nowhere is a true COLD launch. Matches on the stable creation-time
-- initialTitle/initialClass (the current title can change after mapping -- e.g.
-- fzf rewrites it inside the cliphist terminal -- so never match on that).
local function scratchpad_running(match_title)
	for _, w in ipairs(hl.get_windows()) do
		if (w.initial_title == match_title or w.initial_class == match_title) and w.mapped then
			return true
		end
	end
	return false
end

-- Find a scratchpad window by its stable creation-time title/class, but ONLY
-- when it is currently shown (mapped on a normal, non-special workspace).
-- hyprscratch hides a scratchpad by parking it on a special workspace, so this
-- returns nil while hidden -- letting callers skip no-op work (e.g. a delayed
-- re-draw) on a HIDE toggle.
local function find_visible_scratchpad(title)
	for _, w in ipairs(hl.get_windows()) do
		if
			(w.initial_title == title or w.initial_class == title)
			and w.mapped
			and w.workspace
			and not w.workspace.special
			and w.workspace.id > 0
		then
			return w
		end
	end
	return nil
end

-- Toggle a scratchpad, ensuring it grabs focus even while term-focus-guard is
-- armed.
--
-- The guard suppresses the INITIAL focus of any window that maps while armed.
-- hyprscratch's cold-launch path (spawn_normal) relies on that initial focus to
-- land focus on the new window; its warm path (show_normal) focuses explicitly
-- (the guard can't touch it -- the window is already mapped, just moved between
-- workspaces). So a freshly-spawned scratchpad maps UNFOCUSED while the terminal
-- is open -- the "press the hotkey, then press it again just to focus it"
-- symptom reported for Claude, AI Studio, ClickUp, Figma, Neovim, etc.
--
-- Fix: on a COLD launch (app not running yet) while the guard is ARMED, briefly
-- disarm the guard so the new window maps with its normal initial focus, then
-- re-arm it (mirroring terminal visibility) once the window has mapped. Warm
-- toggles (show/hide of an already-running app) never map a new window, so the
-- guard is left untouched -- and the terminal's own focus protection is
-- preserved for everything else.
--
-- (An earlier fix only did this for Calculator + cliphist; every other
-- scratchpad toggled with a bare exec_cmd and so still lost focus on cold
-- launch. This universal version routes them all through the same path.)
local function toggle_scratchpad(name, match_title)
	-- Nothing to fix up unless this is a COLD launch (no matching window exists
	-- anywhere) AND the guard is currently armed (terminal visible). Warm
	-- toggles, and cold launches with the terminal hidden, focus fine already.
	local armed = term_focus_guard ~= nil and term_focus_guard:is_enabled()
	if scratchpad_running(match_title) or not armed then
		hl.exec_cmd("hyprscratch toggle " .. name)
		return
	end

	-- Disarm so the freshly-mapped window receives its initial focus.
	term_focus_guard:set_enabled(false)
	hl.exec_cmd("hyprscratch toggle " .. name)

	-- Re-arm (mirroring terminal visibility) once the window has mapped, or give
	-- up after ~2s. Disarm-first is safe: exec_cmd spawns asynchronously, so the
	-- window can't map before the guard is down.
	local attempts = 0
	local timer
	timer = hl.timer(function()
		attempts = attempts + 1
		if scratchpad_running(match_title) or attempts >= 20 then -- ~2s (20 * 100ms)
			if timer then
				timer:set_enabled(false)
			end
			sync_term_focus_guard()
		end
	end, { timeout = 100, type = "repeat" })
end

-- Re-draw a scratchpad's geometry ({ size = {w,h}, center = true }) after a
-- short delay.
--
-- Some apps -- notably Electron ones like Figma -- map at one size/position and
-- then resize/reposition themselves shortly after opening. hyprscratch applies
-- the scratchpad's `rules` at SHOW time, so a window that reshapes itself
-- afterwards clobbers that geometry and lands in the wrong spot (Figma piles
-- into the bottom-right corner until you nudge it, at which point Hyprland
-- re-lays it out and it snaps to center). Re-asserting the geometry after the
-- app has settled re-draws it where it's supposed to be.
--
-- The toggle may be a SHOW or a HIDE; on HIDE the window is on a special
-- workspace so find_visible_scratchpad returns nil and we correctly no-op.
local function redraw_scratchpad_after(title, geometry, delay_ms)
	hl.timer(function()
		local w = find_visible_scratchpad(title)
		if not w then
			return
		end
		local addr = "address:" .. w.address
		if geometry.size then
			hl.dispatch(hl.dsp.window.resize({
				x = geometry.size[1],
				y = geometry.size[2],
				relative = false, -- exact pixel size (not a delta)
				window = addr,
			}))
		end
		if geometry.center then
			hl.dispatch(hl.dsp.window.center({ window = addr }))
		end
	end, { timeout = delay_ms, type = "oneshot" })
end

----------------------------------------------------------------------
-- Binds
--
-- The terminal is special: it IS the window term-focus-guard protects, so its
-- toggle just syncs the guard rather than disarming it.
hl.bind("ALT + Space", function()
	hl.exec_cmd("hyprscratch toggle terminal")
	-- hyprscratch toggle is async; re-check visibility shortly after it settles.
	hl.timer(sync_term_focus_guard, { timeout = 150, type = "oneshot" })
end)

-- Every other scratchpad goes through toggle_scratchpad so they all grab focus
-- on cold launch while the guard is armed. `name` is the hyprscratch toggle id;
-- `title` is the window's creation-time initialTitle (per hyprscratch.conf),
-- used only to tell a cold launch from a warm toggle. Add new scratchpads here
-- (and define them in hyprscratch.conf) -- they pick up the focus behavior for
-- free.
local scratchpads = {
	-- System monitor
	{ key = "SUPER + b", name = "btop", title = "btop" },
	-- Calculator (two keys -> same toggle)
	{ key = "ALT + SUPER + C", name = "Calculator", title = "Calculator" },
	{ key = "XF86Calculator", name = "Calculator", title = "Calculator" },
	-- Collaboration tools
	{ key = "SUPER + U", name = "ClickUp", title = "ClickUp" },
	{ key = "ALT + SUPER + M", name = "Signal", title = "Signal" },
	{ key = "SUPER + M", name = "Mattermost", title = "Mattermost" },
	{ key = "ALT + SUPER + U", name = "Docmost", title = "Docmost" },
	{ key = "SUPER + V", name = "Jitsi_Meet", title = "Jitsi Meet" },
	{ key = "SUPER + Y", name = "YouTube_Music", title = "YouTube Music" },
	{ key = "SUPER + I", name = "Zoho_Mail", title = "Zoho Mail" },
	-- AI Studio (two Brave profiles)
	{
		key = "SUPER + A",
		name = "AI_Studio_Profile_0",
		title = "brave-mojogeknlbnppmajemmkcfkilgaapppk-Profile_0",
	},
	{
		key = "ALT + SUPER + A",
		name = "AI_Studio_Profile_1",
		title = "brave-mojogeknlbnppmajemmkcfkilgaapppk-Profile_1",
	},
	-- Claude Desktop
	{ key = "SUPER + C", name = "Claude", title = "Claude" },
	-- Obsidian: Neovim (neovide) + the flatpak GUI
	{ key = "SUPER + Semicolon", name = "neovide-obsidian-vault", title = "neovide-obsidian-vault" },
	{ key = "ALT + SUPER + Semicolon", name = "obsidian", title = "obsidian" },
	-- Clipboard history
	{ key = "SUPER + Return", name = "cliphist", title = "cliphist" },
}

for _, sp in ipairs(scratchpads) do
	local name, title = sp.name, sp.title -- capture for the closure
	hl.bind(sp.key, function()
		toggle_scratchpad(name, title)
	end)
end

-- Figma -- Electron reshapes the window after it maps, clobbering the
-- size+center hyprscratch applies at show time (it piles into the bottom-right
-- until nudged). Re-draw 0.5s later, once it has settled, using the same
-- geometry as the Figma rules in hyprscratch.conf. (match title is
-- "figma-linux": under XWayland Electron sets initialTitle to "figma-linux",
-- see hyprscratch.conf for why.)
hl.bind("SUPER + ALT + F", function()
	toggle_scratchpad("Figma", "figma-linux")
	redraw_scratchpad_after("figma-linux", { size = { 3560, 2060 }, center = true }, 500)
end)
