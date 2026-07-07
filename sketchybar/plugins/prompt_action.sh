#!/usr/bin/env bash
# Action for the prompts popup menu. $1 = prompt id. Dismisses the popup, then
# types the prompt via Hammerspoon. Keystroke simulation (not paste) so Claude
# Code's TUI renders it inline instead of collapsing into a [Pasted text]
# attachment. The prompt text + typing live in hammerspoon/init.lua
# (PROMPTS / PastePrompt) -- one source of truth, shared with the
# ctrl+shift+cmd+c hotkey. Wired ONLY to click_script (runs on a real click).
source "$CONFIG_DIR/colors.sh"  # robust PATH so `hs` / `sketchybar` resolve
sketchybar --set prompts popup.drawing=off
hs -c "PastePrompt('$1')" >/dev/null 2>&1
