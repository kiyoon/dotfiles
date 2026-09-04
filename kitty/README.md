# kitty config and usage

Ported from [../wezterm/wezterm.lua](../wezterm/wezterm.lua).

> [!NOTE]
> Needs `font-noto-color-emoji` (in `../install-nerdfont.sh`). wezterm bundles
> Noto Color Emoji; kitty would otherwise fall back to Apple Color Emoji, which
> looks nothing like it in the tmux dracula status bar.

> [!NOTE]
> No terminfo setup needed locally, unlike wezterm. For remote servers,
> `kitten ssh myserver` copies the terminfo automatically. When using plain
> `ssh` instead, run `./terminfo.sh myserver` once (no argument installs
> locally), same usage as `../wezterm/terminfo.sh`.

> [!NOTE]
> `macos.conf` sets `env PATH` explicitly. kitty started from the Dock inherits
> launchd's minimal PATH, and kittens **kitty** launches (as opposed to ones you
> run from a shell) inherit it too — so `choose-files` previews could not find
> `ffprobe` and failed with `executable file not found in $PATH`. Video previews
> need `ffmpeg`; e-book covers need calibre's `ebook-meta`, which is not
> installed.

## Keys

Same as the wezterm config:

- `Shift+Enter`: send CSI-u `ESC[13;2u` so tmux can forward it (Codex multiline)
- `Cmd+Shift+R`: reload config
- `Cmd+Shift+F2` / `Cmd+Shift+F3`: previous tab, `Cmd+Shift+F6`: next tab
- `Cmd+1`..`Cmd+9`: go to that tab; the number is the one the tab shows
- `Ctrl+Shift+Left/Right`: move tab
- `Cmd+Shift+D`: detach pane into a new window, `Cmd+Shift+C`: into a new tab
- `Ctrl+Shift+Alt+|`: split pane right, `Ctrl+Shift+Alt+_`: split pane down
- `Shift+Up/Down`: scroll to previous/next prompt (OSC 133)
- `Cmd+=` / `Cmd+-`: font size (`Ctrl+Shift` variants disabled on macOS)
- `Cmd+Shift+E`: wezterm's custom hyperlink rules as hints ([hyperlinks.py](hyperlinks.py)):
  bare `user/repo` → GitHub, `🔗🐍 [E101]` ruff docs, shellcheck/rustc/clippy/
  biome/luals/selene links, `(URL)`/`[URL]` bracket handling. Keyboard-selected
  instead of wezterm's hover+click, matched from raw text (no OSC 8).

Useful kitty defaults (same muscle memory as wezterm):

- `Cmd+T` new tab, `Cmd+W` close tab, `Ctrl+Shift+W` close pane
- `Cmd+Shift+[` / `Cmd+Shift+]` or `Ctrl+Tab` switch tabs
- Middle-click a tab to close it (kitty tabs have no × button);
  double-click empty tab bar area for a new tab, drag tabs to re-order

kitty built-ins replacing wezterm features:

- Quick select mode (`Ctrl+Shift+Space` in wezterm) → hints kitten:
  `Ctrl+Shift+E` opens a URL by keyboard, `Ctrl+Shift+P` prefixes path/word/line
  hints (`?f` insert path, `?n` open path at line in editor, ...)
- Plain URLs are underlined on hover and open on click, no config needed

## Vertical tabs

`Cmd+Shift+B`, or **View → Toggle Vertical Tabs** in the macOS menubar, flips
`tab_bar_edge` between `top` and `left`. A left sidebar gives every tab title a
row to itself, which is worth the columns it costs when the tabs are agents with
long titles; the horizontal bar splits a single row between all of them.

**View → Sidebar: Small / Medium / Large** set the width, to 12, 20 and 32
title cells, which came out as 20, 28 and 35 columns of sidebar; 20 cells is
kitty's own default. Each one sets the edge too, so picking a size while the tab
bar is horizontal switches to the sidebar in a single click, and the width it
sets survives the toggle back and forth.

The sidebar is not mouse-resizable, and cannot be made so from config. kitty
marks no border zone at the tab bar edge, so there is nothing to grab — the
borders between split windows are drag-resizable, this one is not. Every other
mouse event over the bar is spoken for as well: a click that misses a tab opens
a new tab, a scroll is discarded, and `mouse_map` bindings never fire there.
`tab_title_max_length` is the whole of the width control, which is why the
presets exist. Vertical tabs arrived in kitty 0.48.0, so this may yet grow
upstream.

[toggle-tab-bar-edge.sh](toggle-tab-bar-edge.sh) does the flip. kitty ships no
remote control command that sets an arbitrary option, so the script reads the
edge in force out of kitty's effective config
(`~/Library/Caches/kitty/effective-config/<kitty pid>`, last match wins) and
reloads the config with the other value as a `-o` override. A later reload
re-applies that override rather than dropping it, so the edge holds while
kitty.conf is edited, and nothing is written to disk, so quitting kitty returns
it to the `tab_bar_edge top` in kitty.conf.

There is no button in the titlebar because kitty exposes no API to put one
there, and a click on the tab bar that lands outside a tab is hardwired to open
a new tab. The macOS global menubar is the piece of kitty chrome that a
`menu_map` entry can give the mouse.

## Hammerspoon integration

`hammerspoon/terminal.lua` drives kitty the same way it drives wezterm (F18
Korean/English switching, tmux-prefix detection, prompt insertion). It needs the
remote control settings in `kitty.conf`:

```
allow_remote_control socket-only
listen_on unix:/tmp/kitty
```

kitty appends its own pid, so the socket is `/tmp/kitty-<pid>` and Hammerspoon
builds that path straight from `hs.application:pid()`. `socket-only` means
programs running *inside* a pane cannot drive kitty; only local processes that
can open the socket.

> [!IMPORTANT]
> `listen_on` cannot be applied by reloading the config. kitty windows started
> before these lines existed have no socket, and Hammerspoon silently falls back
> (no F12, no prompt insertion) until kitty is fully quit (⌘Q) and reopened.

## Not ported

- Tab bar hover styles and new-tab-button colors.
- `tmux_restore_agents_menu.lua` still opens WezTerm when no terminal is running;
  that is a launcher preference, not terminal detection.
- Ordered font fallback (`Fira Code Nerd Font` second); kitty uses OS fallback.
