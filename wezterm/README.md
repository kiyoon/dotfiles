# WezTerm config and usage

## Keys

- `Ctrl + Shift + Space`: [Quick select mode](https://wezfurlong.org/wezterm/quickselect.html)

## Settings for Ubuntu

Add `Open with Wezterm` context menu and make Ctrl+Alt+t open wezterm.

Use [nautilus-open-any-terminal](https://github.com/Stunkymonkey/nautilus-open-any-terminal)

```bash
sudo apt update && sudo apt install -y python3-nautilus
pip install --user nautilus-open-any-terminal
nautilus -q
gsettings set com.github.stunkymonkey.nautilus-open-any-terminal terminal wezterm
gsettings set com.github.stunkymonkey.nautilus-open-any-terminal keybindings '<Ctrl><Alt>t'
```
