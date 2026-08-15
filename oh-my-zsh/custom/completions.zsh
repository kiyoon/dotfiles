if (( $+commands[pixi] )); then
	eval "$(pixi completion --shell zsh)"
fi

# bun completions
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"
