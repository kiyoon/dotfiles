CURRENT_DIR="${0:a:h}"
DOTFILES_DIR=$(git -C "$CURRENT_DIR" rev-parse --show-toplevel)
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


dotupdate() {
	git -C "$DOTFILES_DIR" pull
	"$DOTFILES_DIR"/nvim/install-linux.sh
	nvim --headless '+Lazy update' +qall

	~/.tmux/plugins/tpm/scripts/install_plugins.sh
	~/.tmux/plugins/tpm/scripts/update_plugin.sh all

	"$DOTFILES_DIR"/oh-my-zsh/apps-local-install.sh

	"$DOTFILES_DIR"/symlink.sh

	omz reload
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
