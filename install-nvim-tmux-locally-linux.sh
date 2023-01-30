#!/usr/bin/env bash

# neovim latest stable version
mkdir ~/.local/bin -p
cd ~/.local/bin
curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim.appimage
chmod u+x nvim.appimage
./nvim.appimage --appimage-extract
rsync -a squashfs-root/usr/ ~/.local/
rm nvim.appimage
rm -rf squashfs-root

# tmux latest version
mkdir ~/.local/bin -p
cd ~/.local/bin
curl -s https://api.github.com/repos/kiyoon/tmux-appimage/releases/latest \
| grep "browser_download_url.*appimage" \
| cut -d : -f 2,3 \
| tr -d \" \
| wget -qi - \
&& chmod +x tmux.appimage
./tmux.appimage --appimage-extract
rsync -a squashfs-root/usr/ ~/.local/
rm tmux.appimage
rm -rf squashfs-root
