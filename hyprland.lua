-- This file sources other files in `hyprland` and `custom` folders
-- You wanna add your stuff in files in `custom`

-- Internal stuff --
require("hyprland.lib")
require("hyprland.services")

-- Environment variables --
require("hyprland.env")
if is_file_exists(HOME .. "/.config/hypr/custom/env.lua") then
	require("custom.env")
end

-- Default configurations --
require("hyprland.execs")
require("hyprland.general")
require("hyprland.rules")
require("hyprland.colors")
require("hyprland.keybinds")

-- Custom configurations --
if is_file_exists(HOME .. "/.config/hypr/custom/execs.lua") then
	require("custom.execs")
end
if is_file_exists(HOME .. "/.config/hypr/custom/general.lua") then
	require("custom.general")
end
if is_file_exists(HOME .. "/.config/hypr/custom/rules.lua") then
	require("custom.rules")
end
-- Unbinds MUST load after end4-dots keybinds (required above) but BEFORE custom
-- keybinds/hyprscratch, so reclaimed keys (SUPER+V/A/B/M/Tab/...) are free to rebind.
if is_file_exists(HOME .. "/.config/hypr/custom/unbinds.lua") then
	require("custom.unbinds")
end
if is_file_exists(HOME .. "/.config/hypr/custom/keybinds.lua") then
	require("custom.keybinds")
end
if is_file_exists(HOME .. "/.config/hypr/custom/hyprscratch.lua") then
	require("custom.hyprscratch")
end

-- nwg-displays support --
if is_file_exists(HOME .. "/.config/hypr/workspaces.lua") then
	require("workspaces")
end
if is_file_exists(HOME .. "/.config/hypr/monitors.lua") then
	require("monitors")
end

-- Shell overrides --
require("hyprland.shellOverrides.main")
