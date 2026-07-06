# SketchyBar + AeroSpace integration

**Date:** 2026-07-06
**Status:** Approved (menu bar replacement + "solid starter" content confirmed by user)

## Goal

Add a SketchyBar status bar to this dotfiles repo, integrated with the existing
AeroSpace setup. The macOS menu bar auto-hides and SketchyBar replaces it at the
top of every display.

## Decisions

- **Menu bar:** auto-hide the macOS menu bar; SketchyBar takes its place.
- **Content (v1):** left = AeroSpace workspaces + focused app name;
  right = clock/date, battery, volume, Wi-Fi SSID.
- **Config style:** plain-shell SketchyBar config (`sketchybarrc` + `plugins/*.sh`),
  no SbarLua dependency.
- **Fonts:** JetBrainsMono Nerd Font (already installed) for icons and labels.
- **Startup:** `brew services start sketchybar` (survives reboot, easy to remove).
  AeroSpace remains manual-start as configured.

## Layout

```
dotfiles/
  sketchybar/
    sketchybarrc            # bar + defaults + item declarations
    colors.sh               # shared palette
    plugins/
      aerospace_workspaces.sh
      front_app.sh
      clock.sh
      battery.sh
      volume.sh
      wifi.sh
```

`symlink.sh` gains `ln_sb sketchybar ~/.config` in the darwin block
(SketchyBar reads `~/.config/sketchybar/sketchybarrc`).

## Dynamic workspaces (the non-standard part)

This repo's AeroSpace workspaces are dynamic: numbered 1–30, created and
destroyed on demand by `aerospace/scripts/workspace.sh`. Standard tutorials
assume a fixed 1–9 set, so instead:

- `sketchybarrc` pre-creates `space.1` … `space.30` with `drawing=off`.
- A hidden controller item subscribes to a custom `aerospace_workspace_change`
  event (plus `forced` and `system_woke`).
- On each event, `plugins/aerospace_workspaces.sh` queries
  `aerospace list-workspaces --monitor all --empty no` and the focused
  workspace, then issues **one batched** `sketchybar --set …` call that toggles
  `drawing` and the focused highlight for all 30 items. No add/remove churn,
  no reordering problems, no flicker.
- Visible = non-empty workspaces ∪ focused workspace (so a fresh empty
  workspace from `alt-shift-f` still shows).
- Clicking a workspace item runs `aerospace workspace <n>`.

## AeroSpace wiring (`aerospace/aerospace.toml`)

```toml
after-startup-command = ['exec-and-forget sketchybar --trigger aerospace_workspace_change']

exec-on-workspace-change = ['/bin/bash', '-c',
  'sketchybar --trigger aerospace_workspace_change FOCUSED_WORKSPACE=$AEROSPACE_FOCUSED_WORKSPACE'
]
```

Top outer gap: 12 → 48 (36px bar + 12px gap, keeping the 12px rhythm).

## Edge cases

- **launchd PATH:** brew-services SketchyBar runs with a minimal PATH, so every
  plugin and `click_script` uses absolute paths (`/opt/homebrew/bin/aerospace`)
  or exports PATH explicitly.
- **AeroSpace not running:** workspace plugin exits quietly; the rest of the
  bar still works.
- **Workspace IDs > 30** (the `date +%s` fallback in `workspace.sh`): not shown
  in the bar. Accepted for v1.
- **No battery / no Wi-Fi:** those items hide themselves.
- **Menu bar auto-hide:** set via `defaults write NSGlobalDomain _HideMenuBar
  -bool true`; if the OS ignores it, the manual path is System Settings →
  Control Center → "Automatically hide and show the menu bar" → Always.

## Rollback

Everything is additive: `brew services stop sketchybar`, revert the
`aerospace.toml` gap/hook lines, re-show the menu bar, delete the symlink.

## Verification

1. `brew services list` shows sketchybar running; `sketchybar --query bar` responds.
2. Workspace items match `aerospace list-workspaces --empty no`; focused is highlighted.
3. Switching workspaces (f8/f10) and creating one (`alt-shift-f`) updates the bar.
4. Clock/battery/volume/wifi items render; clicking a workspace focuses it.
