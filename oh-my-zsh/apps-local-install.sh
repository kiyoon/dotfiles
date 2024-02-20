#!/usr/bin/env bash

INSTALL_DIR="$HOME/.local"
CARGO="$HOME/.cargo/bin/cargo"
PIP3="/usr/bin/python3 -m pip"

if [[ $OSTYPE == "darwin"* ]]; then
	INSTALL_DIR="$HOME/.local"

	brew install wget

	##### oh-my-zsh
	if [ ! -d "$HOME/.oh-my-zsh" ]; then
		sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended --keep-zshrc
	fi

	brew install zoxide
	brew install fzf
	brew install pipx
	brew install thefuck
	brew install starship
	brew install virtualenvwrapper
	brew install uv

	$PIP3 install --user pygments # colorize (ccat)
	$PIP3 install --user pillow   # my custom ranger viu image viewer uses this

	# install ranger from github
	TEMPDIR=$(mktemp -d)
	git clone --depth=1 https://github.com/ranger/ranger "$TEMPDIR"
	$PIP3 install --user "$TEMPDIR"

	brew install fd
	brew install tig
	brew install eza

	brew install gh
	gh extension install github/gh-copilot
	gh extension upgrade gh-copilot

	brew install jq
	brew install viu
	brew install bat
	brew install bottom
	brew install dust
	brew install procs
	brew install csvlens
	brew install helix
else
	##### oh-my-zsh
	if [ ! -d "$HOME/.oh-my-zsh" ]; then
		sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended --keep-zshrc
	fi

	##### zoxide
	if ! command -v zoxide &>/dev/null; then
		curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
	fi

	##### fzf
	if ! command -v fzf &>/dev/null; then
		git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
		~/.fzf/install --bin
	fi

	##### Starship prompt
	if ! command -v starship &>/dev/null; then
		sh -c "$(curl -fsSL https://starship.rs/install.sh)" sh -b "$INSTALL_DIR/bin" -y
	fi

	$PIP3 install --user pygments # colorize (ccat)
	$PIP3 install --user thefuck  # fix last command
	$PIP3 install --user pillow   # my custom ranger viu image viewer uses this
	$PIP3 install --user virtualenvwrapper
	$PIP3 install --user uv

	# install ranger from github
	TEMPDIR=$(mktemp -d)
	git clone --depth=1 https://github.com/ranger/ranger "$TEMPDIR"
	$PIP3 install --user "$TEMPDIR"

	if ! command -v fd &>/dev/null; then
		npm install -g fd-find
	fi

	if ! command -v tig &>/dev/null; then
		if [ -z "$INSTALL_DIR/include/ncurses/curses.h" ]; then
			echo "Ncurses not found in $INSTALL_DIR/include"
			echo "It should have been installed with zsh-local-install.sh"
			echo "Skipping installing tig."
		else
			TEMPDIR=$(mktemp -d)
			curl -s https://api.github.com/repos/jonas/tig/releases/latest |
				grep "browser_download_url.*.tar.gz" |
				grep tig | grep -v .sha256 |
				cut -d : -f 2,3 |
				tr -d \" |
				wget -qi - -O - | tar xzf - -C "$TEMPDIR" --strip-components=1
			cd "$TEMPDIR"

			./configure prefix=$INSTALL_DIR \
				CPPFLAGS="-I$INSTALL_DIR/include" \
				LDFLAGS="-L$INSTALL_DIR/lib"
			make
			make install
			echo "tig install at $(which tig)"
			\rm -rf "$TEMPDIR"
		fi
	else
		echo "tig already install at $(which tig). Skipping.."
	fi

	if ! command -v eza &>/dev/null; then
		$CARGO install eza
		wget https://raw.githubusercontent.com/eza-community/eza/main/completions/zsh/_eza -P "$INSTALL_DIR/share/zsh/site-functions"

		echo "eza install at $(which eza)"
	else
		echo "eza already install at $(which eza). Skipping.."
	fi

	if ! command -v gh &>/dev/null; then
		TEMPDIR=$(mktemp -d)
		curl -s https://api.github.com/repos/cli/cli/releases/latest |
			grep "browser_download_url.*_linux_amd64.tar.gz" |
			cut -d : -f 2,3 |
			tr -d \" |
			wget -qi - -O - | tar xvzf - -C $TEMPDIR --strip-components=1
		\rm "$TEMPDIR/LICENSE"
		rsync -av "$TEMPDIR/" "$INSTALL_DIR/"
		echo "gh install at $(which gh)"
		\rm -rf "$TEMPDIR"
	else
		echo "gh already install at $(which gh). Skipping.."
	fi
	gh extension install github/gh-copilot
	gh extension upgrade gh-copilot

	if ! command -v jq &>/dev/null; then
		curl -s https://api.github.com/repos/stedolan/jq/releases/latest |
			grep "browser_download_url.*jq-linux64" |
			cut -d : -f 2,3 |
			tr -d \" |
			wget -qi - -O "$INSTALL_DIR/bin/jq"
		chmod +x "$INSTALL_DIR/bin/jq"
		echo "jq install at $(which jq)"
	else
		echo "jq already install at $(which jq). Skipping.."
	fi

	if ! command -v lazygit &>/dev/null; then
		curl -s https://api.github.com/repos/jesseduffield/lazygit/releases/latest |
			grep "browser_download_url.*_Linux_x86_64.tar.gz" |
			cut -d : -f 2,3 |
			tr -d \" |
			wget -qi - -O - | tar xzf - -C "$INSTALL_DIR/bin"
		echo "lazygit install at $(which lazygit)"
	else
		echo "lazygit already install at $(which lazygit). Skipping.."
	fi

	if ! command -v ai &>/dev/null; then
		npm install -g @builder.io/ai-shell
	fi

	if ! command -v bat &> /dev/null; then
		$CARGO install bat
	fi
	$CARGO install viu # --features=sixel
	$CARGO install bottom
	$CARGO install du-dust
	$CARGO install procs
	$CARGO install csvlens

	if ! command -v hx &>/dev/null; then
		wget https://github.com/helix-editor/helix/releases/download/23.10/helix-23.10-x86_64.AppImage -O "$INSTALL_DIR/bin/hx"
		chmod +x "$INSTALL_DIR/bin/hx"
	else
		echo "hx already install at $(which hx). Skipping.."
	fi
fi

