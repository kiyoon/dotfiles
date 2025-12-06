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

	tmpdir=$(dirname $(mktemp -u))
	if [ -n "$TMUX" ]; then
		echo "$(pwd)" > $tmpdir/t_pwd.txt
		tmux detach
	else
		if [ -f $tmpdir/t_pwd.txt ]; then
			cd "$(cat $tmpdir/t_pwd.txt)"
		fi
	fi

}

ssh_delete() {
	ssh-add -d ~/.ssh/id_ed25519
}

git_config() {
	git config --global user.email "kiyoon@users.noreply.github.com"
	git config --global user.name "Kiyoon Kim"
	git config --global core.editor nvim
	git config --global pull.rebase false
	git config --global url.ssh://git@github.com/.insteadOf https://github.com/
	git config --global gpg.format ssh
	git config --global user.signingkey ~/.ssh/id_ed25519.pub
	git config --global commit.gpgsign true

}

git_amend_author() {
	git commit --amend --author="Kiyoon Kim <kiyoon@users.noreply.github.com>"
}

get_sum_bytes() {
	# Calculate the total size of files/directories
	infiles=("${@:1}")
	if [[ $OSTYPE == "darwin"* ]]; then
		sum_bytes=$(($(du -sk "${infiles[@]}" | awk '{print $1}' | paste -s -d+ - | bc) * 1024))
	elif [[ $OSTYPE == "linux"* ]]; then
		sum_bytes=$(du -sb "${infiles[@]}" | awk '{print $1}' | paste -s -d+ - | bc)
	fi
	echo "$sum_bytes"
}

tgz() {
	# Create a tar.gz file with progress bar

	if ! command -v pv &> /dev/null; then
		echo "pv command not found. Please install pv."
		return 1
	fi

	if [ $# -eq 1 ]; then
		# If only one argument is given, use the same name for outfile
		# strip the trailing slash if it exists
        local name=$1
        [[ $name == */ ]] && name=${name%/}
		outfile="$name.tar.gz"
		infiles=("$name")
	else
		outfile="$1"
		infiles=("${@:2}")
	fi

	if [ -z "$infiles" ] || [ -z "$outfile" ]; then
		echo "Usage: tgz [outfile] [infiles..]"
		echo "   or: tgz [infile]  # to create a tar.gz file with the same name"
		return 1
	fi

	if [ -f "$outfile" ]; then
		echo "File already exists: $outfile"
		return 1
	fi

	for infile in "${infiles[@]}"; do
		if [ ! -d "$infile" ] && [ ! -f "$infile" ]; then
			echo "File not found: $infile"
			return 1
		fi
	done

	sum_bytes=$(get_sum_bytes "${infiles[@]}")
	tar --exclude='.DS_Store' --exclude='*/.DS_Store' \
        -cf - "${infiles[@]}" \
        | pv -s $sum_bytes \
        | gzip > "$outfile"
}

tzst() {
	# Create a tar.zst file with progress bar
	# uses -1 compression (fastest) for now.

	if ! command -v zstd &> /dev/null; then
		echo "zstd command not found. Please install zstd."
		return 1
	fi

	if ! command -v pv &> /dev/null; then
		echo "pv command not found. Please install pv."
		return 1
	fi

	if [ $# -eq 1 ]; then
		# If only one argument is given, use the same name for outfile
		# strip the trailing slash if it exists
        local name=$1
        [[ $name == */ ]] && name=${name%/}
		outfile="$name.tar.zst"
		infiles=("$name")
	else
		outfile="$1"
		infiles=("${@:2}")
	fi

	if [ -z "$infiles" ] || [ -z "$outfile" ]; then
		echo "Usage: tzst [outfile] [infiles..]"
		echo "   or: tzst [infile]  # to create a tar.zst file with the same name"
		return 1
	fi

	if [ -f "$outfile" ]; then
		echo "File already exists: $outfile"
		return 1
	fi

	for infile in "${infiles[@]}"; do
		if [ ! -d "$infile" ] && [ ! -f "$infile" ]; then
			echo "File not found: $infile"
			return 1
		fi
	done

	sum_bytes=$(get_sum_bytes "${infiles[@]}")
	tar --exclude='.DS_Store' --exclude='*/.DS_Store' \
        -cf - "${infiles[@]}" \
        | pv -s $sum_bytes \
        | zstd -T0 -1 > "$outfile"
}

tzsti() {
	# Make a tar.zst with a tree index file call .tree.txt
	if ! command -v zstd &> /dev/null; then
		echo "zstd command not found. Please install zstd."
		return 1
	fi

	if ! command -v pv &> /dev/null; then
		echo "pv command not found. Please install pv."
		return 1
	fi

	if [ $# -eq 1 ]; then
		# If only one argument is given, use the same name for outfile
		# strip the trailing slash if it exists
        local name=$1
        [[ $name == */ ]] && name=${name%/}
		outfile="$name.tar.zst"
		outtree="$name.tree.txt"
		infiles=("$name")
	else
		outfile="$1"
		outtree="${outfile%.tar.zst}.tree.txt"
		infiles=("${@:2}")
	fi

	if [ -z "$infiles" ] || [ -z "$outfile" ]; then
		echo "Usage: tzsti [outfile] [infiles..]"
		echo "   or: tzsti [infile]  # to create a tar.zst file with the same name"
		return 1
	fi

	if [ -f "$outfile" ]; then
		echo "File already exists: $outfile"
		return 1
	fi

	for infile in "${infiles[@]}"; do
		if [ ! -d "$infile" ] && [ ! -f "$infile" ]; then
			echo "File not found: $infile"
			return 1
		fi
	done

	eza -Tla --icons=always --ignore-glob='.DS_Store' "${infiles[@]}" > "$outtree"
	tzst "$outfile" "${infiles[@]}"
}

osc52copy() {
	if [ -z "$1" ]; then
		echo "Usage: osc52copy [text]"
		return 1
	fi
	#printf $'\e]52;c;%s\a' "$(base64 <<<'hello world')"
	printf $'\e]52;c;%s\a' "$(base64 <<< "$1")"
}

# Inspired from oh-my-zsh/plugins/copypath but uses osc52
cppath() {
	# If no argument passed, use current directory
	local file=$(realpath "${1:-.}")
	osc52copy "$file"
}

# copy the contents of a file to the clipboard
cpfile() {
	if [ -z "$1" ]; then
		echo "Usage: cpfile [file]"
		return 1
	fi
	osc52copy "$(\cat "$1")"
}

# Ctrl+O to copy current command to clipboard
cpbuffer() {
	if [ -z "$BUFFER" ]; then
		echo "No command to copy"
		return 1
	fi
	osc52copy "$BUFFER"
}
zle -N cpbuffer
bindkey "^O" cpbuffer

## backup utils
dust_exclude_tarzst_dirs() {
	# find all *.tar.zst and exclude the directories with the same name (without the .tar.zst extension)
	# because they are already archived.
	if [ -z "$1" ]; then
		dust_dir="."
	else
		dust_dir="$1"
	fi

	# 1. Build a -X /path/to/file list in an array
	excargs=( )
	while read file; do
	    excargs+=( -X "$file" )
	done < <(find "$dust_dir" -type f -name '*.tar.zst' | sed 's|.tar.zst$||')

	# 2. Run dust with the -X options
	dust "$dust_dir" "${excargs[@]}" "${@:2}"
}

azcopy_exclude_tarzst_dirs() {
	# find all *.tar.zst and exclude the directories with the same name (without the .tar.zst extension)
	# because they are already archived.
	if [ -z "$1" ]; then
		echo 'Usage: azcopy copy [source] [destination] --exclude-path $(azcopy_exclude_tarzst_dirs [source])'
		echo "Unlike dust_exclude_tarzst_dirs, this function does not call azcopy, but prepares the arguments for it."
		echo ''
		return 1
	fi

	find . -type f -name '*.tar.zst' | sed 's|.tar.zst$||' | paste -sd ';' -
}

# rename python module with basedpyright
pymv() {
	DOTFILES_DIR=$(dotfiles_dir)
	bun ${DOTFILES_DIR}/oh-my-zsh/scripts/basedpyright-tools/rename_module.ts "$@"
}
