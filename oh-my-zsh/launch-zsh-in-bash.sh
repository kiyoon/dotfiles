#!/usr/bin/env bash

if cat ~/.bashrc | grep -q '# Launch ZSH in Bash'; then
	echo "ZSH already launched in Bash"
else
	echo 'Add lines to ~/.bashrc'
	echo '# Launch ZSH in Bash' >>~/.bashrc
	echo 'export PATH="$HOME/.local/bin:$PATH"' >>~/.bashrc
	echo 'if [[ ($- == *i*) ]]' >>~/.bashrc
	echo 'then' >>~/.bashrc
	echo '    export SHELL=$(which zsh)' >>~/.bashrc
	echo '    exec zsh -l' >>~/.bashrc
	echo 'fi' >>~/.bashrc
fi
