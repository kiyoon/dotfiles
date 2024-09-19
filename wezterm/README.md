# WezTerm config and usage

> [!WARNING]
> If you set `config.term = "wezterm"`, you must download the terminfo file using `terminfo.sh` on your local computer and every server you connect to.
> If not, you will see weird things happening in the terminal.
>
> You get extended features such as image protocols and undercurl (curly underline).
>
> You can change to `config.term = "xterm-256color"` for better compatibility.

## Keys

- `Ctrl + Shift + Space`: [Quick select mode](https://wezfurlong.org/wezterm/quickselect.html)

## Settings for Ubuntu

Add `Open with Wezterm` context menu and make Ctrl+Alt+t open wezterm.

Use [nautilus-open-any-terminal](https://github.com/Stunkymonkey/nautilus-open-any-terminal)

```bash
sudo apt update && sudo apt install -y python3-nautilus
pip install --user nautilus-open-any-terminal
nautilus -q
glib-compile-schemas ~/.local/share/glib-2.0/schemas/
gsettings set com.github.stunkymonkey.nautilus-open-any-terminal terminal wezterm
gsettings set com.github.stunkymonkey.nautilus-open-any-terminal keybindings '<Ctrl><Alt>t'
```

UPDATE: The keybindings may not work. On Ubuntu, use this command.

```bash
sudo update-alternatives --config x-terminal-emulator
```
