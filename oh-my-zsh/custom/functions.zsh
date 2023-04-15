DOTFILES_OHMYZSH_CUSTOM_DIR="${0:a:h}"

ghremote() {
	if [ $# -eq 1 ]; then
		if [[ "$1" = *"/"* ]]; then
			reponame="$1"
		else
			reponame=kiyoon/"$1"
		fi
		echo "git remote add origin https://github.com/$reponame"
		git remote add origin "https://github.com/$reponame"
	elif [ $# -eq 2 ]; then
		if [[ "$2" = *"/"* ]]; then
			reponame="$2"
		else
			reponame=kiyoon/"$2"
		fi
		echo "git remote add $1 https://github.com/$reponame"
		git remote add "$1" "https://github.com/$reponame"
	else
		echo "Usage: ghremote [remotename=origin] [username]/[reponame]"
		echo "Example: ghremote kiyoon/awesome"
		echo "Example2: ghremote awesome (kiyoon can be skipped)"
		return 1
	fi
}

dotfiles_dir() {
	DOTFILES_DIR=$(git -C "$DOTFILES_OHMYZSH_CUSTOM_DIR" rev-parse --show-toplevel)
	echo "$DOTFILES_DIR"
}

dotstash() {
	DOTFILES_DIR=$(dotfiles_dir)
	git -C "$DOTFILES_DIR" stash
}

dotinstall() {
	DOTFILES_DIR=$(dotfiles_dir)
	"$DOTFILES_DIR"/oh-my-zsh/apps-local-install.sh

	"$DOTFILES_DIR"/nvim/install-linux.sh
	nvim +"lua require('lazy').restore({wait=true})" +qa

	"$DOTFILES_DIR"/tmux/install-plugins.sh
	"$DOTFILES_DIR"/tmux/update-plugins.sh

	"$DOTFILES_DIR"/wezterm/terminfo.sh

	"$DOTFILES_DIR"/symlink.sh

	omz reload
}

dotupdate() {
	checkout="$1"
	DOTFILES_DIR=$(dotfiles_dir)
	git -C "$DOTFILES_DIR" pull
	if [ $? -ne 0 ]; then
		echo
		print -P "%F{red}Failed to update dotfiles due to local changes.%f"
		print -P "%F{red}To discard local changes and force update, run %f"
		echo
		echo "dotstash"
		echo
		print -P "%F{red}and try again%f"
		return 1
	fi
	git -C "$DOTFILES_DIR" submodule update --init --remote

	if [ -n "$checkout" ]; then
		git -C "$DOTFILES_DIR" checkout "$checkout"
	fi

	# omz reload
	source ~/.zshrc
	dotinstall
}

dotstable() {
	dotupdate stable
}

license() {
	if [ $# -ne 1 ]; then
		echo "Usage: license [name]"
		echo
		echo "Available licenses:"
		curl -s https://api.github.com/licenses | jq -r '.[].key'
		return 1
	fi

	curl -s "https://api.github.com/licenses/$1" | jq -r '.body'
}
