#!/usr/bin/env bash
# Action for the prompts popup menu. $1 = prompt id. Dismisses the popup, then
# inserts the prompt via Hammerspoon. Small line-aware paste chunks keep it
# editable instead of collapsing it into a [Pasted text] attachment. The prompt
# text + insertion logic live in hammerspoon/init.lua
# (PROMPTS / PastePrompt) -- one source of truth, shared with the
# ctrl+shift+cmd+c hotkey. Wired ONLY to click_script (runs on a real click).
source "$CONFIG_DIR/colors.sh"  # robust PATH so `hs` / `sketchybar` resolve
sketchybar --set prompts popup.drawing=off
hs -c "PastePrompt('$1')" >/dev/null 2>&1
