# SketchyBar

Custom [SketchyBar](https://github.com/FelixKratz/SketchyBar) config, integrated with
[AeroSpace](https://github.com/nikitabobko/AeroSpace).

**Left:** transient gaming-stop gamepad/result · AeroSpace mode badge · workspaces `1‑30`
(grouped per monitor with dividers) · front app. The gaming item is absent at rest.
**Right:** clock · combined battery/native charge limit · volume · Bluetooth `Boucles soniques` · Wi‑Fi (with
**un‑redacted SSID**) · cpu/gpu/ram · input source (한/A) · Amphetamine ·
cached Codex and Claude quota meters.

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
- [Tailscale for macOS](https://tailscale.com/docs/install/mac) with its CLI installed, and
  [Moonlight](https://github.com/moonlight-stream/moonlight-qt). The gaming-stop menu action uses
  Tailscale to reach the Windows host while closing Moonlight independently as soon as selected.
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
- `helpers/battery_charge_limit` — reads and sets the native macOS manual charge limit while
  keeping Optimized Battery Charging enabled. It loads PowerUI at runtime and hides the button
  cleanly on unsupported Macs or macOS releases.
- `helpers/codexbar_usage_watcher` — watches CodexBar's atomically replaced widget snapshot,
  reproduces its 18-point Codex and Claude two-bar icons, and updates only when cached data
  changes. A 60-second local-file safety check recovers missed events after sleep; neither path
  asks CodexBar or a provider to refresh.

To force a rebuild:

```bash
rm helpers/tis_current helpers/input_watcher helpers/bluetooth_boucles_watcher \
  helpers/battery_charge_limit helpers/codexbar_usage_watcher
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
Start / Restart clears the marker. It also contains **Stop Windows gaming
session**, whose progress and result appear temporarily at the far-left edge of
SketchyBar. Directly below that action are tmux actions that can save the latest
`main` snapshot and stop tmux, or resume the latest `main` or `cron` snapshot.
The AeroSpace CLI equivalents are:

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

### Combined native battery charge-limit readout

On an Apple-silicon Mac running macOS 26.4 or later, the two touching click zones render as one
readout such as `74≤80%`. Clicking the battery icon/current-charge region opens Battery Settings;
clicking the blue `≤80%` suffix cycles `80% → 90% → 95% → 100% → 80%`. The exact suffix avoids
ambiguity at 95%. A red `!80%` means the configured policy is not currently active. The 100% choice leaves
**Optimized Battery Charging enabled**, so it requests full capacity without disabling Apple's
battery protection. Button clicks refresh immediately, while a change made separately in System
Settings is picked up by the 30-second poll. Apple's native policy may still occasionally charge to
100% to calibrate its state-of-charge estimate, as documented in
[Apple's Charge Limit guide](https://support.apple.com/102338).

The helper uses macOS's private PowerUI client because Apple exposes the feature in System
Settings and Shortcuts but not through a command-line utility. If a future macOS update changes
that client, only the limit suffix hides instead of displaying or applying a guessed limit; the
current-charge region restores its ordinary `%` suffix.

## 6. Windows gaming-stop action

Choose **Stop Windows gaming session** from the Hammerspoon reload/restart menu
to end the `windows-tail` gaming session with this workflow:

Save game progress before selecting it: this is intentionally a one-click shutdown action.

1. Immediately start the local Moonlight shutdown branch. Send `TERM` to its verified app PID;
   during an active stream, Moonlight 6.1 may use the first signal to end the session while leaving
   its main window open. After a two-second cleanup window, a second `TERM` closes the app; if the
   same original PID remains after one more second, only that PID receives a final `KILL` fallback.
2. Concurrently prepare SSH and read Tailscale's machine state. If Tailscale is not `Running`, open
   it, run a bounded `tailscale up`, and wait for the interface to become ready.
3. Use non-interactive SSH to run `plugins/steam_stop.ps1` in PowerShell on Windows. The helper
   accepts exactly one Steam AppID only when Steam's registry, `gameprocess_log.txt`, and live
   process tree agree, and the live Steam executable matches a valid Valve signature. It asks
   Steam to stop that AppID without a force flag, confirms the game is gone, then requests
   `steam.exe -shutdown` and confirms Steam exited.
4. Wait for both local and remote branches. The transient status reports `Failed` if either one fails.

Moonlight shutdown is deliberately independent: once the menu action is accepted, it continues even
if Tailscale, authentication, SSH, game shutdown, or Steam shutdown fails. A failed branch still
reports `Failed` rather than hiding the partial result.

There is no public Steam API that lets an external utility reliably stop the local active game.
The [Steam Web API](https://partner.steamgames.com/doc/webapi/ISteamUser) can expose
presence/current-game information when privacy settings allow it, but it cannot control the
client. This helper therefore uses a local Steam client command after cross-checking Steam's own
local state. It never uses `taskkill`, `Stop-Process`, or a forced Steam `app_stop`; ambiguity or
timeout fails closed and Steam is not shut down while a game is still reported running.

No separate Moonlight “disconnect” action is needed here. Its first termination request tears
down the client stream while the independent Windows branch stops the host game and Steam.
Closing Moonlight by itself does not stop the host game, so both branches must still complete.

Prerequisites:

- Tailscale must already be installed and logged in once. A first-time browser login cannot be
  completed from the SketchyBar menu action.
- `windows-tail` must resolve in `~/.ssh/config` and accept key-based SSH with
  `BatchMode=yes`. The SSH Windows account must be the same account that is running Steam.
- SketchyBar runs under launchd and does not inherit the interactive terminal's custom SSH
  agent. The plugin safely reads only `SSH_AUTH_SOCK` from `~/.ssh/agent.env`, which this
  dotfiles setup's `.zshrc` already maintains. The referenced agent must still be running and
  contain the key shown by `ssh-add -l`; the plugin never reads or copies a private key.
- The SSH command pins `~/.ssh/id_ed25519` with `IdentitiesOnly=yes`, disables implicit agent
  mutation, and enables macOS `UseKeychain`. Today the loaded custom agent unlocks that encrypted
  key; if its passphrase is later stored in Keychain, the same command can also work without it.
  After a fresh login or agent-key expiry, unlock the key in that custom agent once before using
  the action; until then, authentication fails closed and Moonlight is preserved.
- `pwsh.exe` (PowerShell 7) must be available on the Windows `PATH`.

The PowerShell helper defaults to a read-only probe unless its caller explicitly sets stop mode.
This command deliberately removes the current terminal's agent variable, then exercises the
same `~/.ssh/agent.env` authentication path used by SketchyBar without closing anything:

```bash
env -u SSH_AUTH_SOCK \
  ~/.config/sketchybar/plugins/gaming_stop.sh probe
```

The far-left status appears with a gamepad only while the action is running and for its brief result:
`Game stopped`, `Steam stopped`, or `No Steam running`; errors show `Failed`. Its fixed 150-point
width prevents the neighboring icons from moving when the label changes, then the whole item disappears.
Detailed output is appended to `$TMPDIR/sketchybar_gaming_stop.log` (normally under the per-user
macOS temporary directory).

## Troubleshooting

- **Codex/Claude quota meter is missing** → open CodexBar once and confirm
  `~/Library/Group Containers/Y5PE65HELJ.com.steipete.codexbar/widget-snapshot.json` exists,
  then `sketchybar --reload`. A missing second Codex lane is intentional: CodexBar puts the
  first available window on top and leaves the lower track dim. If the snapshot format changed,
  uncomment `CODEXBAR_DISPLAY_MODE=alias` in `sketchybarrc` as a temporary fallback.
- **Amphetamine item is missing** → Amphetamine isn't running or its Automation permission
  was denied. Launch it and allow `sketchybar` to control it.
- **Charge-limit item is missing** → it requires an Apple-silicon Mac on macOS 26.4 or later.
  Confirm Xcode Command Line Tools are installed, remove `helpers/battery_charge_limit`, and run
  `sketchybar --reload` to rebuild it.
- **Wi‑Fi shows an icon but no name** → `wifi-unredactor` isn't installed or Location isn't
  granted (§4). Run the app once and click Allow; confirm it's enabled in Location Services.
- **한/A input badge not updating** → the `input_watcher` daemon isn't running; `sketchybar
  --reload` relaunches it.
- **Bluetooth indicator not changing instantly** → the `bluetooth_boucles_watcher` daemon isn't
  running or Bluetooth permission was denied; `sketchybar --reload` relaunches it.
- **Gaming-stop status shows `Failed`** → inspect `$TMPDIR/sketchybar_gaming_stop.log`. Common
  causes are a first-time Tailscale login, an offline Windows host, SSH prompting instead of
  key authentication, more than one Steam AppID reported running, or Steam not confirming a
  graceful game/client exit before the bounded timeout. For `Permission denied (publickey)`,
  confirm `~/.ssh/agent.env` names a live socket and that `SSH_AUTH_SOCK=<that socket> ssh-add -l`
  lists the Windows key, then run the read-only probe above.
- **Workspace numbers/app glyphs missing** → install both fonts (§1) and ensure AeroSpace is
  running (it fires the workspace‑change events).
- **Edges of hidden workspace windows visible in a bottom corner** → AeroSpace
  emulates workspaces by parking inactive windows off-screen, and macOS leaves
  a one-pixel edge. If more is visible, arrange displays so each monitor has a
  free bottom-left or bottom-right corner.
