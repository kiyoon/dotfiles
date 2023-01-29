#!/usr/bin/env bash

mkdir -p ~/.config
ln -srb nvim ~/.config
ln -srb nvim/.vimrc ~
ln -srb tmux/.tmux.conf ~
ln -srb oh-my-zsh/.zshrc ~
ln -srb oh-my-zsh/starship.toml ~/.config
ln -srb wezterm ~/.config
ln -srb cargo/config.toml ~/.cargo
# ln -srb git/.gitconfig ~
