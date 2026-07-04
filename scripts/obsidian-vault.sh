#!/usr/bin/env bash
# Launch Neovim (via Neovide) in the Obsidian vault as a hyprscratch scratchpad.
#
# Why a script instead of inlining in hyprscratch.conf:
# hyprscratch v0.6.3's `command` parser mishandles nested quotes, so a
# `bash -lc '... --cmd "..." ...'` value silently fails to exec (spawns nothing).
# hyprscratch execs this single path with no args, sidestepping the parser.
#
# Initial state is set two ways the nvim config actually honors:
#   NVIM_AUTOSAVE=1     -> lua/user/config.lua reads this env var to seed
#                          g:autosave_enabled. (A --cmd flag would be clobbered
#                          by that line, which is why it never worked before.)
#                          Toggle at runtime with :AutosaveToggle / <leader>ua.
#   custom_titlestring  -> makes the window title "neovide-obsidian-vault" so
#                          hyprscratch can match/hide/show it (see lua/config.lua).
cd "$HOME/Documents/Obsidian Vault" || exit 1
export NVIM_AUTOSAVE=1
exec neovide --no-fork --no-tabs -- \
  --cmd "let g:custom_titlestring = 'neovide-obsidian-vault'"
