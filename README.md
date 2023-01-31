# dotfiles

## Steps

1. Install dotfiles

```bash
cd ~/.config	# it doesn't have to be here. Just install anywhere
git clone https://github.com/kiyoon/dotfiles
```

2. Install neovim and tmux

For linux, you can install locally using:

```bash
./install-nvim-tmux-locally-linux.sh
./wezterm/terminfo.sh	# if you're using wezterm you need this terminfo database
```

This will download the latest appimage for each and extract at `~/.local/bin`.

3. Install zsh, oh-my-zsh

See [oh-my-zsh/README.md](oh-my-zsh/README.md)

4. Symlink dotfiles and install others

```bash
# WARNING: ./symlink.sh will override existing dotfiles without validation (but will create a backup).
# The old dotfiles will be moved with '~' suffix.
# Use with care if you configured something manually.
./symlink.sh
./install-nerdfont.sh
```

5. Install / Update dotfiles, apps, plugins etc.

```zsh
# WARNING: This includes calling ./symlink.sh so the dotfile symlinks will be updated.
dotupdate
```
