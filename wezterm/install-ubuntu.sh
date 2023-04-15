#!/usr/bin/env bash
TEMP_DIR=$(mktemp -d)
curl -s https://api.github.com/repos/wez/wezterm/releases/latest |
	grep "browser_download_url.*.Ubuntu22.04.deb" |
	cut -d : -f 2,3 |
	tr -d \" |
	wget -qi - -O "$TEMP_DIR/wezterm.deb"

sudo dpkg -i "$TEMP_DIR/wezterm.deb"
