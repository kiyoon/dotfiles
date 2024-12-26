if (($+commands[bat])); then
	alias cat='bat'
fi

if (($+commands[eza])); then
	# sl is defined in mistakes.zsh
	alias ls='eza --icons auto --hyperlink'
	alias ll='eza -alF --icons auto --hyperlink'
	alias la='eza -a --icons auto --hyperlink'
	alias l='eza -F --icons auto --hyperlink'
	alias lg='eza --git-ignore --icons auto --hyperlink'
fi

if (($+commands[nvim])); then
	# vi is defined in mistakes.zsh
	alias v='nvim'
	alias vim='vim'
	alias vimdiff='nvim -d'
	alias vic='NVIM_APPNAME=nvim-coc nvim'
	alias lazyvim='NVIM_APPNAME=nvim-lazyvim nvim'
	alias csvi='nvim -u ~/.config/nvim/csv_init.lua'
	alias svi='sudoedit'
	alias dv='nvim +DiffviewOpen'
fi

alias src='omz reload'
alias ns='nvidia-smi'
alias rb='gio trash'
