export PATH="$HOME/.cargo/bin:$HOME/.local/bin:$PATH"
export LD_LIBRARY_PATH="$HOME/.local/lib:$LD_LIBRARY_PATH"
export MANPATH="$HOME/.local/share/man:$MANPATH"

export TERMINFO="$HOME/.local/share/terminfo"  # tmux needs this

# setup fzf Ctrl+t and Alt+c
if (( $+commands[fzf] )); then
	if (( $+commands[fd] )); then
		export FZF_DEFAULT_OPTS='-m --bind ctrl-s:select-all,ctrl-d:deselect-all,ctrl-t:toggle-all'
		export FZF_DEFAULT_COMMAND='fd --type f --hidden --exclude .git'
		export FZF_CTRL_T_COMMAND='fd --type f --hidden --exclude .git'
		export FZF_ALT_C_COMMAND='fd --type d --hidden --exclude .git'
	fi
fi
