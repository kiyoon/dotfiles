#!/bin/bash

# https://jdhao.github.io/2018/10/13/centos_zsh_install_use/
# Install zsh under ~/.local/bin/zsh

INSTALL_DIR="$HOME/.local"
mkdir -p "$HOME/bin" && cd "$HOME/bin"

wget ftp://ftp.gnu.org/gnu/ncurses/ncurses-6.1.tar.gz
tar xf ncurses-6.1.tar.gz
cd ncurses-6.1
./configure --prefix="$INSTALL_DIR" CXXFLAGS="-fPIC" CFLAGS="-fPIC"
make -j && make install


ZSH_SRC_NAME=$HOME/bin/zsh.tar.xz
ZSH_PACK_DIR=$HOME/bin/zsh
ZSH_LINK="https://sourceforge.net/projects/zsh/files/latest/download"

if [[ ! -d "$ZSH_PACK_DIR" ]]; then
    echo "Creating zsh directory under packages directory"
    mkdir -p "$ZSH_PACK_DIR"
fi

if [[ ! -f $ZSH_SRC_NAME ]]; then
    curl -Lo "$ZSH_SRC_NAME" "$ZSH_LINK"
fi

tar xJvf "$ZSH_SRC_NAME" -C "$ZSH_PACK_DIR" --strip-components 1
cd "$ZSH_PACK_DIR"

./configure --prefix="$INSTALL_DIR" \
    CPPFLAGS="-I$INSTALL_DIR/include" \
    LDFLAGS="-L$INSTALL_DIR/lib"
make -j && make install

\rm "$ZSH_SRC_NAME"
\rm -rf "$ZSH_PACK_DIR"
\rm "$HOME/bin/ncurses-6.1.tar.gz"
\rm -rf "$HOME/bin/ncurses-6.1"

echo "zsh installed under $INSTALL_DIR/bin/zsh"
