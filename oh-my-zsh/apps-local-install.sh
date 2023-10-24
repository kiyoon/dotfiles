#!/usr/bin/env bash

INSTALL_DIR="$HOME/.local"

##### oh-my-zsh
if [ ! -d "$HOME/.oh-my-zsh" ]; then
	sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended --keep-zshrc
fi

##### conda
if ! command -v conda &>/dev/null; then
	wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
	CONDADIR="$HOME/bin/miniconda3"
	mkdir -p "$HOME/bin"
	bash Miniconda3-latest-Linux-x86_64.sh -b -p "$CONDADIR"
	rm Miniconda3-latest-Linux-x86_64.sh
	$CONDADIR/bin/conda init
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

pip3 install --user pygments # colorize (ccat)
pip3 install --user thefuck  # fix last command

if ! command -v "$INSTALL_DIR/bin/npm" &>/dev/null; then
	curl -sL install-node.vercel.app/lts | bash -s -- --prefix="$INSTALL_DIR" -y
fi

# rustup, cargo
if ! command -v rustup &>/dev/null; then
	curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | bash -s -- -y
fi

if ! command -v fd &>/dev/null; then
	"$INSTALL_DIR/bin/npm" install -g fd-find
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

if ! command -v exa &>/dev/null; then
	TEMPDIR=$(mktemp -d)
	curl -s https://api.github.com/repos/ogham/exa/releases/latest |
		grep "browser_download_url.*exa-linux-x86_64-musl-v" |
		cut -d : -f 2,3 |
		tr -d \" |
		wget -qi - -O $TEMPDIR/exa.zip
	unzip "$TEMPDIR/exa.zip" -d $TEMPDIR
	# mv "$TEMPDIR/bin/"* "$INSTALL_DIR/bin"
	mv "$TEMPDIR/man/"*.1 "$INSTALL_DIR/share/man/man1"
	mv "$TEMPDIR/man/"*.5 "$INSTALL_DIR/share/man/man5"
	mv "$TEMPDIR/completions/exa.zsh" "$INSTALL_DIR/share/zsh/site-functions/_exa"

	# Exa with git support
	~/.cargo/bin/cargo install exa

	echo "exa install at $(which exa)"
	\rm -rf "$TEMPDIR"
else
	echo "exa already install at $(which exa). Skipping.."
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

# if ! command -v gotop &> /dev/null
# then
#     curl -s https://api.github.com/repos/xxxserxxx/gotop/releases/latest \
#         | grep "browser_download_url.*_linux_amd64.tgz" \
#         | cut -d : -f 2,3 \
#         | tr -d \" \
#         | wget -qi - -O - | tar xzf - -C "$INSTALL_DIR/bin"
#             echo "gotop install at $(which gotop)"
#         else
#             echo "gotop already install at $(which gotop). Skipping.."
# fi

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
	"$INSTALL_DIR/bin/npm" install -g @builder.io/ai-shell
fi

if ! command -v aicommits &>/dev/null; then
	"$INSTALL_DIR/bin/npm" install -g aicommits
fi

~/.cargo/bin/cargo install viu # --features=sixel
~/.cargo/bin/cargo install bat
~/.cargo/bin/cargo install bottom
~/.cargo/bin/cargo install du-dust
~/.cargo/bin/cargo install procs
~/.cargo/bin/cargo install csvlens
