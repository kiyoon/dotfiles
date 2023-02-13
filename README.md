# dotfiles that work without sudo

This is a modern Neovim, Tmux, Zsh configuration that supports installing everything locally (i.e. non-system-wide user install, not using sudo).  
You can enjoy working on a remote SSH server without a root permission, just like you do locally.

If you're on mac, use `brew` to install everything. The scripts assume Linux.

You can refer to README in each directory for details of each program!

## Keep it stable!

This repository includes a Github Actions that automatically checks if the commit hasn't been made for 1 week.  
If it has not been updated for 1 week, we consider that commit to be 'stable' and automatically bump version with `stable` tag.  
In order to try the stable version, just run `dotstable` after setting up the zsh. This will also pull neovim plugin versions that have been used for the stable commit.

## Steps

1. Install dotfiles

```bash
cd ~/.config	# it doesn't have to be here. Just install anywhere
git clone https://github.com/kiyoon/dotfiles
```

2. Install neovim and tmux

You need Neovim v0.9.0. The fold column will look ugly in v0.8.x.

On Linux, you can install locally using:

```bash
./install-nvim-tmux-locally-linux.sh
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
dotupdate			# Use if you want to update to the latest commit
dotstable			# Use if you want to use the stable tag
dotupdate <tag>		# Specify the tag/commit you want to use
```
