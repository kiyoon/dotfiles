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

	if [[ $OSTYPE != "darwin"* ]]; then
		"$DOTFILES_DIR"/install-nvim-tmux-locally-linux.sh
	fi
	"$DOTFILES_DIR"/oh-my-zsh/apps-local-install.sh

	"$DOTFILES_DIR"/nvim/install-dependencies.sh
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

is_gpg_cached() {
	# https://unix.stackexchange.com/questions/71135/how-can-i-find-out-what-keys-gpg-agent-has-cached-like-how-ssh-add-l-shows-yo

	subkeygrip=$(gpg --list-secret-keys --with-keygrip | grep ssb -A1 | grep Keygrip | awk '{print $3}')
	if [ -z "$subkeygrip" ]; then
		echo "nogpg"
		return 1
	fi

	cached=$(gpg-connect-agent 'keyinfo --list' /bye | grep "$subkeygrip" | awk '{print $7}')
	if [ "$cached" = "1" ]; then
		echo "true"
		return 0
	elif [ "$cached" = "-" ]; then
		echo "false"
		return 0
	else
		echo "nogpg"
		return 1
	fi
}

override_term_program() {
	# Force resetting TERM_PROGRAM to wezterm
	# This is required to view images over ssh
	export TERM_PROGRAM=WezTerm
	export TERM_PROGRAM_VERSION=20230712-072601-f4abf8fd
}

t() {
	# 1. If inside tmux
	# Save current directory to /tmp/t_pwd.txt 
	# and detach from tmux

	# 2. If not inside tmux
	# If /tmp/t_pwd.txt exists, cd to that directory

	if [ -n "$TMUX" ]; then
		tmpdir=$(dirname $(mktemp -u))
		echo "$(pwd)" > $tmpdir/t_pwd.txt
		tmux detach
	else
		if [ -f /tmp/t_pwd.txt ]; then
			cd "$(cat /tmp/t_pwd.txt)"
		fi
	fi

}

git_config() {
	git config --global user.email "kiyoon@users.noreply.github.com"
	git config --global user.name "Kiyoon Kim"
	git config --global core.editor nvim
	git config --global pull.rebase false
	git config --global url.ssh://git@github.com/.insteadOf https://github.com/
}

