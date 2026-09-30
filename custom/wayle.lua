-- Wayle integration (the ii -> Wayle shell port; see the wayle-config repo).
--
-- Owns the Hyprland side of the port: the shell-coupled keybind transfer
-- (feature-map v3 §4, authoritative HI edit plan). Required at the tail of
-- custom/keybinds.lua, right after the winmode require, inside the same
-- pcall-guard pattern: an error here must never take the user's keybinds
-- down. The wayle-bar layer rules live in wayle-layers.lua, staged
-- separately (docs/wayle-lua-staged-reintro.md: binds and layer rules must
-- never land together — 09:36 incident suspect (b) isolation).
--
-- Split in two halves:
--   * IMMEDIATE binds — safe while the user still runs quickshell/ii: they
--     only replace dead quickshell globals (dispatches into globals the
--     running ii does not register), binds to missing tools (hyprshot,
--     ii's record.sh), and the stale pre-ii `agsv1` binds. Landing these
--     FIXES currently-broken keys instead of regressing live ones.
--   * CUTOVER-GATED removals — binds that drive LIVE ii features today
--     (sidebars, cheatsheet, session screen, welcome popup). They stay
--     untouched until ~/.config/wayle/state/cutover.done exists. The
--     user-run `wayle-cutover --apply` creates that marker and triggers
--     `hyprctl reload`; this module re-evaluates on every reload, so the
--     removals activate exactly at cutover (and vanish again on rollback).
--
-- Hard constraint (RESPONSIBILITIES): hyprscratch.lua owns SUPER+R/b/C/U/M/
-- V/I/A/Return/Semicolon/Y, ALT+SUPER+M/C/A/U/Semicolon/F, XF86Calculator,
-- ALT+Space, and the bare SUPER_L/R binds — none of those are touched here.

-- Paths. exec_cmd strings run through a shell, so $HOME expands (same
-- convention as hyprland/keybinds.lua's $HOME/.config/quickshell/... paths).
local WAYLE = "$HOME/.config/wayle/scripts"
local WRAP = "$HOME/.config/hypr/custom/scripts/wayle"

----------------------------------------------------------------------
-- IMMEDIATE: repoint dead / stale / broken shell binds to the wayle
-- scripts. Every repoint unbinds the exact old key string first (duplicates
-- coexist in Hyprland — both the dead global and its fallback fire today).
----------------------------------------------------------------------

-- Timewarrior (qs-timew port). Old: quickshell:timewarrior* globals.
hl.unbind("SUPER + g")
hl.unbind("ALT + SUPER + g")
hl.bind("SUPER + g", hl.dsp.exec_cmd(WAYLE .. "/timew/timew-toggle"), { description = "Wayle: Timewarrior start/stop" })
hl.bind("ALT + SUPER + g", hl.dsp.exec_cmd(WAYLE .. "/timew/timew-edit-tags"), { description = "Wayle: Timewarrior edit tags" })

-- Bar visibility pin toggle (autohide daemon CLI). Old: stale `agsv1
-- run-js ...` binds (keybinds.lua:343-344) — agsv1 has been gone for ages.
hl.unbind("SUPER + Z")
hl.unbind("ALT + SUPER + Z")
hl.bind("SUPER + Z", hl.dsp.exec_cmd(WAYLE .. "/autohide/wayle-bar-pin toggle"), { description = "Wayle: Bar pin toggle (current monitor)" })
hl.bind("ALT + SUPER + Z", hl.dsp.exec_cmd(WAYLE .. "/autohide/wayle-bar-pin toggle --all"), { description = "Wayle: Bar pin toggle (all monitors)" })

-- Emoji: ii's overviewEmojiToggle global -> the user's launcher (verified:
-- `vicinae cmd list` has core:search-emojis).
hl.unbind("SUPER + e")
hl.bind("SUPER + e", hl.dsp.exec_cmd("vicinae cmd launch core:search-emojis"), { description = "Wayle: Emoji search (vicinae)" })

-- Window cycling. The dead quickshell:cyclenext global (overview grid has no
-- wayle vehicle) used to double-bind SUPER+Tab alongside the native
-- cycle_next; strip both, keep one clean native bind.
hl.unbind("SUPER + Tab")
hl.bind("SUPER + Tab", hl.dsp.window.cycle_next(), { description = "Window: Cycle next" })

-- Window switcher. Old: dead quickshell:overviewWorkspacesToggle global.
hl.unbind("ALT + SUPER + Tab")
hl.bind("ALT + SUPER + Tab", hl.dsp.exec_cmd("vicinae cmd launch wm:switch-windows"), { description = "Wayle: Window switcher (vicinae)" })

-- Panel restart. Old: `killall ydotool qs quickshell; qs -c $qsConfig &` —
-- would murder the user's LIVE quickshell during the trial; repointing it is
-- the safe direction. The stable wrapper resolves the installed wayle.
hl.unbind("CTRL + SUPER + R")
hl.bind("CTRL + SUPER + R", hl.dsp.exec_cmd(WRAP .. " panel restart"), { description = "Wayle: Restart panel" })

-- Wallpaper picker (old: wallpaperSelector globals + switchwall fallbacks).
hl.unbind("CTRL + SUPER + T")
hl.unbind("CTRL + SUPER + ALT + T")
hl.bind("CTRL + SUPER + T", hl.dsp.exec_cmd(WAYLE .. "/wallpaper/wayle-wallpaper"), { description = "Wayle: Wallpaper picker" })
hl.bind("CTRL + SUPER + ALT + T", hl.dsp.exec_cmd(WAYLE .. "/wallpaper/wayle-wallpaper --random"), { description = "Wayle: Random wallpaper" })

-- Region snip / OCR / Google Lens / screen recording: WITHHELD 2026-09-19 —
-- capture.lua (the user's own quickshell-free suite) owns these keys with
-- live, working binds; see the SUPERSEDED note in this file's header.

-- Light/dark toggle — RETIRED (run 7H, 2026-09-22 user directive: "never
-- worked, but I don't need it — I'll always use the dark theme").
-- Wayle is statically dark: theme-provider=wayle + hardcoded dark
-- [styling.palette] (themes/ii-material.toml). The bind called
-- scripts/colors/wayle-dark-mode → vendor-ii/switchwall.sh → quickshell
-- config/cache/state — the LAST runtime quickshell dependency, now
-- severed. Old: dead quickshell:toggleLightDark global. If a theme
-- surface is ever wanted again: the dashboard quick-actions row is the
-- agreed home (see docs/design/bar-visual-review-12-FIXNOTES.md).
hl.unbind("CTRL + SUPER + SHIFT + D")

----------------------------------------------------------------------
-- CUTOVER-GATED removals.
--
-- Everything below drives LIVE quickshell/ii features right now; removing
-- any of it pre-cutover would regress the user's active session. The marker
-- file is created by the USER-RUN `wayle-cutover --apply` (which then
-- triggers a reload so this block takes effect) and removed by --rollback.
----------------------------------------------------------------------

local cutover_done = false
do
	local home = HOME or os.getenv("HOME") -- HOME is a hyprland.lib global
	local f = io.open(home .. "/.config/wayle/state/cutover.done")
	if f then
		f:close()
		cutover_done = true
	end
end

if cutover_done then
	-- Sidebars: dropped by the port (AI/weeb left sidebar excluded by mission;
	-- right sidebar's functions live in bar modules now). SUPER+A/ALT+A/B are
	-- hyprscratch/user keys and were never sidebar binds (D3) — untouched.
	hl.unbind("SUPER + O") -- sidebarLeftToggle
	hl.unbind("SUPER + N") -- sidebarRightToggle

	-- Cheatsheet: stretch not landed; docs/keybinds.md replaces it.
	hl.unbind("SUPER + Slash") -- cheatsheetToggle

	-- Region translate: WITHHELD 2026-09-19 — capture.lua's live
	-- screenshot_translate.sh bind owns SUPER+SHIFT+T (the old "dead global,
	-- already inert" premise is stale); this unbind must NOT fire at cutover.
	-- hl.unbind("SUPER + SHIFT + T") -- screenTranslate

	-- Panel family cycle: no wayle equivalent (bar layout is static).
	-- SUPER+ALT+/ is custom/keybinds.lua's spelling; the default file also
	-- carries the same global on CTRL+SUPER+P (handled below).
	hl.unbind("SUPER + ALT + Slash") -- panelFamilyCycle

	-- FirstRunExperience popup (welcome.qml) — one-time onboarding, dropped.
	hl.unbind("SHIFT + SUPER + ALT + Slash")

	-- CTRL+SUPER+P: strip the dead panelFamilyCycle global that shares the
	-- key with the user's Brave Profile 1 launcher, then re-raise the Brave
	-- bind (exact copy from custom/keybinds.lua).
	hl.unbind("CTRL + SUPER + P")
	hl.bind(
		"CTRL + SUPER + P",
		hl.dsp.exec_cmd("brave --remote-debugging-port=9222 --profile-directory=Profile\\ 1"),
		{ description = "App: Brave Profile 1" }
	)

	-- Session menu: drop the quickshell sessionToggle global, keep the
	-- wlogout fallback (promoted, qs-ipc guard stripped — wlogout's own
	-- pkill makes the key a toggle: open when closed, close when open).
	hl.unbind("CTRL + ALT + Delete")
	hl.bind("CTRL + ALT + Delete", hl.dsp.exec_cmd("pkill wlogout || wlogout -p layer-shell"), { description = "Wayle: Session menu (wlogout)" })

	-- NOTE (left inert on purpose, §4/W3): the bare SUPER_L/R
	-- workspaceNumber binds die with quickshell's global registry and simply
	-- no-op post-cutover; their transparent/ignore_mods flags make touching
	-- them riskier than leaving them.
end
