#!/usr/bin/env bash

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Same as ln -sb (backup if file exists)
# but mac compatible
# note that the second argument must be a directory.
ln_sb() {
	file_relpath="$1"
	dest_dir="$2"

	basename="$(basename "$file_relpath")"
	dest_file="$dest_dir/$basename"

	mkdir -p "$dest_dir"
	if [[ -f "$dest_file" ]] || [[ -d "$dest_file" ]]
	then
		mv "$dest_file" "$dest_file"~
	fi

	ln -s "$CURRENT_DIR/$file_relpath" "$dest_dir"
}

ln_sb nvim ~/.config
ln_sb nvim/.vimrc ~
ln_sb tmux/.tmux.conf ~
ln_sb oh-my-zsh/.zshrc ~
ln_sb oh-my-zsh/starship.toml ~/.config
ln_sb wezterm ~/.config
ln_sb cargo/config.toml ~/.cargo
ln_sb conda/.condarc ~
