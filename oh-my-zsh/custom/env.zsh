export PATH="$HOME/.cargo/bin:$HOME/.local/bin:$PATH"
export LD_LIBRARY_PATH="$HOME/.local/lib:$LD_LIBRARY_PATH"
export MANPATH="$HOME/.local/share/man:$MANPATH"

export TERMINFO="$HOME/.local/share/terminfo" # tmux needs this

if (($ + commands[nvim])); then
	export SUDO_EDITOR="$commands[nvim]"
fi

# setup fzf Ctrl+t and Alt+c
if (($ + commands[fzf])); then
	if (($ + commands[fd])); then
		export FZF_DEFAULT_OPTS='-m --bind ctrl-s:select-all,ctrl-d:deselect-all,ctrl-t:toggle-all'
		export FZF_DEFAULT_COMMAND='fd --type f --hidden --exclude .git'
		export FZF_CTRL_T_COMMAND='fd --type f --hidden --exclude .git'
		export FZF_ALT_C_COMMAND='fd --type d --hidden --exclude .git'
	fi
fi

# Inside tmux, home and end keys don't work
# https://stackoverflow.com/questions/18600188/home-end-keys-do-not-work-in-tmux
# Binding keys in tmux.conf works in neovim but doesn't in zsh or maybe zsh-vi-mode
# so we bind them here so it works in zsh as well.
bindkey "^[OF" end-of-line
bindkey "^[OH" beginning-of-line

# https://unix.stackexchange.com/questions/90853/how-can-i-run-ssh-add-automatically-without-a-password-prompt
if [ -z "$SSH_AUTH_SOCK" ]; then
	eval $(ssh-agent -s)
	# ssh-add
fi
