#!/usr/bin/env bash

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

mkdir -p ~/.config
ln -srb "$CURRENT_DIR"/nvim ~/.config
ln -srb "$CURRENT_DIR"/nvim/.vimrc ~
ln -srb "$CURRENT_DIR"/tmux/.tmux.conf ~
ln -srb "$CURRENT_DIR"/oh-my-zsh/.zshrc ~
ln -srb "$CURRENT_DIR"/oh-my-zsh/starship.toml ~/.config
ln -srb "$CURRENT_DIR"/wezterm ~/.config
mkdir -p ~/.cargo
ln -srb "$CURRENT_DIR"/cargo/config.toml ~/.cargo
ln -srb "$CURRENT_DIR"/conda/.condarc ~
# ln -srb git/.gitconfig ~
