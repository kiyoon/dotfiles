#!/usr/bin/env bash


if [[ $OSTYPE == "darwin"* ]]; then
	brew install neovim
	brew install tmux
else
	## After installing, you need the followings to use nvim and tmux.
	## Don't need to configure this if you use the zsh config in this repo.
	##
	# export PATH="$HOME/.local/bin:$PATH"
	# export LD_LIBRARY_PATH="$HOME/.local/lib:$LD_LIBRARY_PATH"
	# export MANPATH="$HOME/.local/share/man:$MANPATH"
	# export TERMINFO="$HOME/.local/share/terminfo"	# tmux needs this

	# neovim latest stable/nightly version
	# nvim_tag=stable
	# nvim_tag=nightly
	nvim_tag=v0.12.4
	mkdir ~/.local/bin -p
	cd ~/.local/bin || exit
	curl -LO https://github.com/neovim/neovim/releases/download/$nvim_tag/nvim-linux-x86_64.appimage
	chmod u+x ./nvim-linux-x86_64.appimage
	./nvim-linux-x86_64.appimage --appimage-extract
	rsync -a squashfs-root/usr/ ~/.local/
	rm nvim-linux-x86_64.appimage
	rm -rf squashfs-root

	# tmux latest stable x86_64 version. Install terminfo separately with wezterm/terminfo.sh.
	curl -fsSL https://api.github.com/repos/tmux/tmux-builds/releases/latest |
		grep 'browser_download_url.*linux-x86_64.tar.gz' |
		cut -d \" -f 4 |
		xargs curl -fsSL |
		tar -xzf - -C "$HOME/.local/bin" tmux
fi
