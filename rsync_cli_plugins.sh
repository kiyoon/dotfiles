if [[ $# -ne 1 ]]; then
	echo "Usage: $0 <ssh_name>"
	echo "Synchronise ~/.local/bin, ~/.local/share/nvim, ~/.cargo/bin, ~/.tmux to remote server"
	echo "ssh_name is the name of the ssh config entry"
	echo "Useful for servers that don't have good internet access"
	exit 1
fi

ssh_name="$1"

rsync -avz ~/.local/bin $ssh_name:~/.local/
rsync -avz ~/.local/include $ssh_name:~/.local
rsync -avz ~/.local/lib $ssh_name:~/.local
rsync -avz ~/.local/man $ssh_name:~/.local
rsync -avz ~/.local/share/nvim $ssh_name:~/.local/share
rsync -avz ~/.local/share/terminfo $ssh_name:~/.local/share
rsync -avz ~/.local/share/man $ssh_name:~/.local/share
rsync -avz ~/.cargo/bin $ssh_name:~/.cargo/
rsync -avz ~/.tmux $ssh_name:~/
