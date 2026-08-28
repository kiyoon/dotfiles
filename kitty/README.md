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

## Keys

Same as the wezterm config:

- `Shift+Enter`: send CSI-u `ESC[13;2u` so tmux can forward it (Codex multiline)
- `Cmd+Shift+R`: reload config
- `Cmd+Shift+F2` / `Cmd+Shift+F3`: previous tab, `Cmd+Shift+F6`: next tab
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
