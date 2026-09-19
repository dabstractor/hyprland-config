#!/usr/bin/env bash
# OCR a screen region to the clipboard (replaces quickshell:regionOcr).
# Select a region with slurp -> tesseract extracts text -> wl-copy.
set -u

notify() { command -v notify-send >/dev/null && notify-send -t 3000 "$@" >/dev/null 2>&1 || true; }

img=$(mktemp /tmp/ocr_XXXXXX.png)

# Region selection; abort silently if the user presses Escape.
grim -g "$(slurp)" "$img" 2>/dev/null || { rm -f "$img"; exit 0; }

# Build tesseract language pack list, e.g. "eng+deu".
langs=$(tesseract --list-langs 2>/dev/null | tail -n +2 | paste -sd+ -)
lang_args=()
[[ -n "$langs" ]] && lang_args=(-l "$langs")

if tesseract "$img" stdout "${lang_args[@]}" 2>/dev/null | wl-copy; then
	notify "OCR" "Text copied to clipboard"
else
	notify "OCR" "Failed to extract text"
fi

rm -f "$img"
