#!/usr/bin/env bash
# Open the Hammerspoon native comparison menu from its SketchyBar alias.

menu="${1:-displays}"

hs -c "local menus = _G.sketchybarCompareMenubars or {}; if menus['$menu'] then menus['$menu']:popupMenu(hs.mouse.absolutePosition(), true) end"
