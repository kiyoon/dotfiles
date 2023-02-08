# dotfiles that work without sudo

This is a modern Neovim, Tmux, Zsh configuration that supports installing everything locally (i.e. non-system-wide user install, not using sudo).  
You can enjoy working on a remote SSH server without a root permission, just like you do locally.

If you're on mac, use `brew` to install everything. The scripts assume Linux.

## Steps

1. Install dotfiles

```bash
cd ~/.config	# it doesn't have to be here. Just install anywhere
git clone https://github.com/kiyoon/dotfiles
```

2. Install neovim and tmux

On Linux, you can install locally using:

```bash
./install-nvim-tmux-locally-linux.sh
./wezterm/terminfo.sh	# if you're using wezterm you need this terminfo database
```

This will download the latest appimage for each and extract at `~/.local/bin`.

Install neovim dependencies:  
```bash
nvim/install-linux.sh
```

Install tmux plugins:  
```bash
tmux/install-plugins.sh
```

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
