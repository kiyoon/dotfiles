# SketchyBar

Custom [SketchyBar](https://github.com/FelixKratz/SketchyBar) config, integrated with
[AeroSpace](https://github.com/nikitabobko/AeroSpace).

**Left:** AeroSpace mode badge · workspaces `1‑30` (grouped per monitor with dividers) ·
front app.
**Right:** clock · battery · volume · Bluetooth `Boucles soniques` · Wi‑Fi (with
**un‑redacted SSID**) · cpu/gpu/ram · input source (한/A) · Amphetamine · cached
Codex and Claude quota meters.

`~/.config/sketchybar` is symlinked to this directory.

---

## 1. Install prerequisites

```bash
# SketchyBar itself
brew install felixkratz/formulae/sketchybar

# Window manager it integrates with
brew install --cask nikitabobko/tap/aerospace

# Compiler for the Swift helpers — skip if you already have Xcode / its tools
xcode-select --install

# Fonts
brew install --cask font-jetbrains-mono-nerd-font        # icons + text
# sketchybar-app-font (glyphs for the workspace app icons):
curl -L -o ~/Library/Fonts/sketchybar-app-font.ttf \
  https://github.com/kvndrsslr/sketchybar-app-font/releases/latest/download/sketchybar-app-font.ttf
```

**Status apps:**

- [Amphetamine](https://apps.apple.com/app/amphetamine/id937984704) (Mac App Store). Its
  SketchyBar item reads the session state through AppleScript; it is not a screen capture.
- CodexBar (`com.steipete.codexbar`) — supplies the Codex and Claude usage data. SketchyBar
  reads CodexBar's small WidgetKit snapshot from its app-group container and renders two normal
  items with CodexBar's plain merged-icon two-lane geometry. It never invokes
  CodexBar's fetching CLI and does not capture the native menu-bar item. If a future CodexBar
  release changes the cache schema, uncomment `CODEXBAR_DISPLAY_MODE=alias` beside the CodexBar
  block in `sketchybarrc` and reload to fall back to CodexBar's live merged icon.

## 2. Grant permissions — System Settings → Privacy & Security

| Permission | Grant to | Why |
|---|---|---|
| **Screen Recording** *(alias fallback only)* | `sketchybar` | Required only when `CODEXBAR_DISPLAY_MODE=alias`; the default cached items do not capture the screen. |
| **Automation** | `sketchybar` → Amphetamine / System Events | Read and toggle Amphetamine's session state, and open native menu-bar popups without capturing them. macOS prompts on first use. |
| **Location Services** | `wifi-unredactor` | The only way to read the Wi‑Fi SSID on macOS Sonoma+ (see §4). |
| **Accessibility** | `sketchybar` | Click handlers can open native menu‑bar popups, including CodexBar and Bluetooth / Control Center. |
| **Bluetooth** | `sketchybar` / `bluetooth_boucles_watcher` if prompted | The `Boucles soniques` indicator uses IOBluetooth connect/disconnect notifications for instant updates. |
| **Accessibility** | `AeroSpace` | Window management + workspace events. |

## 3. Compiled helpers (built automatically)

`sketchybarrc` compiles these on first load with `swiftc` (hence Xcode CLT above). Sources are
committed; the binaries are git‑ignored.

- `helpers/tis_current` — reads the current text input source (한/A).
- `helpers/input_watcher` — tiny daemon that polls the input API and fires the `input_change`
  event instantly on a source switch.
- `helpers/bluetooth_boucles_watcher` — tiny daemon that listens for IOBluetooth
  connect/disconnect notifications for `Boucles soniques` and fires
  `bluetooth_boucles_change`.
- `helpers/codexbar_usage_watcher` — watches CodexBar's atomically replaced widget snapshot,
  reproduces its 18-point Codex and Claude two-bar icons, and updates only when cached data
  changes. A 60-second local-file safety check recovers missed events after sleep; neither path
  asks CodexBar or a provider to refresh.

To force a rebuild:

```bash
rm helpers/tis_current helpers/input_watcher helpers/bluetooth_boucles_watcher \
  helpers/codexbar_usage_watcher
sketchybar --reload
```

## 4. Wi‑Fi SSID — `wifi-unredactor`

Since macOS Sonoma the SSID is **redacted** from every unprivileged tool — `ipconfig`,
`networksetup`, `system_profiler`, even `sudo wdutil` — unless the calling process holds
**Location Services** permission. The only reliable reader is a Location‑authorized `.app`, so
`wifi.sh` shells out to [`noperator/wifi-unredactor`](https://github.com/noperator/wifi-unredactor)
(an external dependency, not vendored here):

```bash
git clone https://github.com/noperator/wifi-unredactor
cd wifi-unredactor
./build-and-install.sh                        # -> ~/Applications/wifi-unredactor.app
open ~/Applications/wifi-unredactor.app        # click "Allow" on the Location prompt
```

Then **System Settings → Privacy & Security → Location Services → enable `wifi-unredactor`**.
Verify:

```bash
~/Applications/wifi-unredactor.app/Contents/MacOS/wifi-unredactor
# {"interface":"en0","ssid":"YourNetwork","bssid":"aa:bb:cc:dd:ee:ff"}
```

Notes:
- `wifi.sh` calls the app **only** on `wifi_change` / `system_woke` (not every poll) and caches
  the name in `~/.cache/sketchybar_wifi_ssid`.
- Without the app (or the grant), the Wi‑Fi item degrades gracefully to an icon‑only
  "connected / disconnected" state — no name.
- A plain CLI can **not** get this permission to persist; it must be an `NSApplication` in
  `~/Applications` (which is exactly what wifi-unredactor is). If you ever rebuild it, you may
  need to re‑enable it under Location Services.

## 5. Run

```bash
brew services start sketchybar     # start on login + now
sketchybar --reload                # re-apply after editing the config

# AeroSpace: set `start-at-login = true` in aerospace/aerospace.toml and launch it once
open -a AeroSpace
```

Hammerspoon automatically performs one full AeroSpace relaunch after a real
display-topology change has been quiet for five seconds. The watcher is
event-driven (no idle polling), ignores Dock-only screen notifications, and
also runs once after wake because macOS can omit screen events while asleep.
Normal AeroSpace workspace/window changes update the highlighted item
immediately and coalesce a complete workspace/icon reconciliation for 50 ms.
This is event-driven—there is no idle polling—and the live rebuild normally
finishes in well under a second. Actual display transitions create a separate
recovery-pending marker, so their queries remain held while macOS is publishing
a transient monitor layout. A recovery restart leaves a one-shot marker that
makes AeroSpace's startup event perform the full reconciliation immediately
only when both belong to the same display-recovery generation.
SketchyBar's `display_change` event only means that the active display changed;
it follows the normal 50 ms path and does not enter topology recovery.
Workspace scripts also emit a final-state event after multi-command moves, and
AeroSpace window-detection events reconcile icons after a newly launched app is
actually bound to its workspace.
Recovery history is written to `~/.cache/aerospace/recovery.log`; a manual
relaunch uses the same safe path:

```bash
~/.config/aerospace/scripts/restart.sh manual
```

The reload menu also has separate **Stop AeroSpace** and **Start / Restart
AeroSpace** actions. Stop leaves an intentional-stop marker so automatic
display recovery cannot relaunch AeroSpace during a native-fullscreen session;
Start / Restart clears the marker. CLI equivalents are:

```bash
~/.config/aerospace/scripts/restart.sh stop
~/.config/aerospace/scripts/restart.sh manual
```

For the Bluetooth SketchyBar item to open the native macOS popup, Bluetooth must also be shown
as a standalone macOS menu-bar item:

```bash
defaults -currentHost write com.apple.controlcenter Bluetooth -int 18
defaults write com.apple.controlcenter "NSStatusItem Visible Bluetooth" -bool true
killall ControlCenter SystemUIServer
```

Without that native item, clicking falls back to Bluetooth Settings.
The `Boucles soniques` connection indicator is event-driven by
`helpers/bluetooth_boucles_watcher`; it has no periodic `update_freq` polling. The shell plugin
only uses `system_profiler` as a one-shot fallback on reload, wake, or Bluetooth power/status
changes to establish the initial state.

CPU usage uses a normalized `ps` process sum across logical cores, which matches tmux-style CPU
percentages and avoids the old blocking two-sample `top` call.

## Troubleshooting

- **Codex/Claude quota meter is missing** → open CodexBar once and confirm
  `~/Library/Group Containers/Y5PE65HELJ.com.steipete.codexbar/widget-snapshot.json` exists,
  then `sketchybar --reload`. A missing second Codex lane is intentional: CodexBar puts the
  first available window on top and leaves the lower track dim. If the snapshot format changed,
  uncomment `CODEXBAR_DISPLAY_MODE=alias` in `sketchybarrc` as a temporary fallback.
- **Amphetamine item is missing** → Amphetamine isn't running or its Automation permission
  was denied. Launch it and allow `sketchybar` to control it.
- **Wi‑Fi shows an icon but no name** → `wifi-unredactor` isn't installed or Location isn't
  granted (§4). Run the app once and click Allow; confirm it's enabled in Location Services.
- **한/A input badge not updating** → the `input_watcher` daemon isn't running; `sketchybar
  --reload` relaunches it.
- **Bluetooth indicator not changing instantly** → the `bluetooth_boucles_watcher` daemon isn't
  running or Bluetooth permission was denied; `sketchybar --reload` relaunches it.
- **Workspace numbers/app glyphs missing** → install both fonts (§1) and ensure AeroSpace is
  running (it fires the workspace‑change events).
- **Edges of hidden workspace windows visible in a bottom corner** → AeroSpace
  emulates workspaces by parking inactive windows off-screen, and macOS leaves
  a one-pixel edge. If more is visible, arrange displays so each monitor has a
  free bottom-left or bottom-right corner.
