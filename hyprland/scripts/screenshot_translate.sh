#!/usr/bin/env bash
# OCR + translate a screen region to the clipboard (replaces
# quickshell:screenTranslate). Uses translate-shell's `trans` if installed;
# otherwise degrades to plain OCR text with a hint.
#
# Usage: screenshot_translate.sh [target-lang]   (default: en)
set -u
target="${1:-en}"

notify() { command -v notify-send >/dev/null && notify-send -t 3000 "$@" >/dev/null 2>&1 || true; }

img=$(mktemp /tmp/translate_XXXXXX.png)
grim -g "$(slurp)" "$img" 2>/dev/null || { rm -f "$img"; exit 0; }

langs=$(tesseract --list-langs 2>/dev/null | tail -n +2 | paste -sd+ -)
lang_args=()
[[ -n "$langs" ]] && lang_args=(-l "$langs")

text=$(tesseract "$img" stdout "${lang_args[@]}" 2>/dev/null)
rm -f "$img"

if [[ -z "${text//[[:space:]]/}" ]]; then
	notify "Translate" "No text found in region"
	exit 0
fi

if command -v trans >/dev/null; then
	if trans -b ":${target}" "${text}" 2>/dev/null | wl-copy; then
		notify "Translate" "Translation (-> ${target}) copied to clipboard"
	else
		printf '%s' "$text" | wl-copy
		notify "Translate" "Translation failed; original text copied"
	fi
else
	printf '%s' "$text" | wl-copy
	notify "Translate" "translate-shell not installed — copied raw OCR text instead (pacman -S translate-shell)"
fi
