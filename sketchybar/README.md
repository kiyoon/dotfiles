# SketchyBar

Custom [SketchyBar](https://github.com/FelixKratz/SketchyBar) config, integrated with
[AeroSpace](https://github.com/nikitabobko/AeroSpace).

**Left:** AeroSpace mode badge · workspaces `1‑30` (grouped per monitor with dividers) ·
front app.
**Right:** clock · battery · volume · Wi‑Fi (with **un‑redacted SSID**) · cpu/gpu/ram ·
input source (한/A) · Amphetamine · CodexBar.

`~/.config/sketchybar` is symlinked to this directory.

---

## 1. Install prerequisites

```bash
# SketchyBar itself
brew install felixkratz/formulae/sketchybar

# Window manager it integrates with
brew install --cask nikitabobko/tap/aerospace

# Compiler for the Swift helpers (tis_current, input_watcher) — skip if you
# already have Xcode / its tools
xcode-select --install

# Fonts
brew install --cask font-jetbrains-mono-nerd-font        # icons + text
# sketchybar-app-font (glyphs for the workspace app icons):
curl -L -o ~/Library/Fonts/sketchybar-app-font.ttf \
  https://github.com/kvndrsslr/sketchybar-app-font/releases/latest/download/sketchybar-app-font.ttf
```

**Apps shown as menu‑bar aliases** (each must be installed **and running with its menu‑bar
item present** — hidden behind the notch is fine, quit is not):

- [Amphetamine](https://apps.apple.com/app/amphetamine/id937984704) (Mac App Store)
- CodexBar (`com.steipete.codexbar`) — the merged Codex/Claude usage menu‑bar app

## 2. Grant permissions — System Settings → Privacy & Security

| Permission | Grant to | Why |
|---|---|---|
| **Screen Recording** | `sketchybar` | The app aliases (Amphetamine, CodexBar) are live *screen captures* of the real menu‑bar items. Restart sketchybar after granting. |
| **Location Services** | `wifi-unredactor` | The only way to read the Wi‑Fi SSID on macOS Sonoma+ (see §4). |
| **Accessibility** | `AeroSpace` | Window management + workspace events. |

## 3. Compiled helpers (built automatically)

`sketchybarrc` compiles these on first load with `swiftc` (hence Xcode CLT above). Sources are
committed; the binaries are git‑ignored.

- `helpers/tis_current` — reads the current text input source (한/A).
- `helpers/input_watcher` — tiny daemon that polls the input API and fires the `input_change`
  event instantly on a source switch.

To force a rebuild: `rm helpers/tis_current helpers/input_watcher && sketchybar --reload`.

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

## Troubleshooting

- **App alias is blank** → the app isn't running / has no menu‑bar item, or Screen Recording
  isn't granted. Fix, then `sketchybar --reload`.
- **Wi‑Fi shows an icon but no name** → `wifi-unredactor` isn't installed or Location isn't
  granted (§4). Run the app once and click Allow; confirm it's enabled in Location Services.
- **한/A input badge not updating** → the `input_watcher` daemon isn't running; `sketchybar
  --reload` relaunches it.
- **Workspace numbers/app glyphs missing** → install both fonts (§1) and ensure AeroSpace is
  running (it fires the workspace‑change events).
