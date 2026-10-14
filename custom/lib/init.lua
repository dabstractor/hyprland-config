-- Shared helpers for the custom config, namespaced by domain. Mirrors the
-- base config's hyprland/lib/ convention (which exposes globals); each domain
-- here is a module table so nothing leaks into the global namespace.
--
--   require("custom.lib").windows    -> is_locked_terminal, resize_if_ok,
--                                       move_if_ok, move_or_focus,
--                                       cycle_fs_aware, zoomfunction
--   require("custom.lib").workspaces -> delete_workspace, inject_workspace,
--                                       carry_window
--
-- Modules re-evaluate on every `hyprctl reload` (verified: package.loaded is
-- reset per reload), so editing a lib file hot-reloads like any config file.
local M = {}
M.windows = require("custom.lib.windows")
M.workspaces = require("custom.lib.workspaces")
return M
