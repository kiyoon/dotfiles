if (($+commands[bat])); then
	alias cat='bat'
fi

if (($+commands[exa])); then
	alias ls='exa --icons'
	alias ll='exa -alF --icons'
	alias la='exa -a --icons'
	alias l='exa -F --icons'
	alias lg='exa --git-ignore --icons'
fi

if (($+commands[nvim])); then
	alias v='TERM=wezterm nvim'
	alias vi='TERM=wezterm nvim'
	alias vim='TERM=wezterm nvim'
	alias vimdiff='TERM=wezterm nvim -d'
	alias vic='TERM=wezterm NVIM_APPNAME=nvim-coc nvim'
	alias lazyvim='TERM=wezterm NVIM_APPNAME=nvim-lazyvim nvim'
	alias svi='sudoedit'
	alias nvim='TERM=wezterm nvim'
	alias diffview='TERM=wezterm nvim +DiffviewOpen'
	alias dv='TERM=wezterm nvim +DiffviewOpen'
fi

if (($+commands[gh])); then
	alias ghr='gh repo'
	alias ghb='gh browse'
	alias ghc='gh repo clone'
	ghck() {
		gh repo clone kiyoon/$1
	}
fi

alias src='omz reload'

alias ca='conda activate'
alias cc='conda create -n'
alias ns='nvidia-smi'
alias rb='gio trash'

# git
alias cdgit='cd $(git rev-parse --show-toplevel)'

# slurm
alias sq='squeue -u $USER'
idamnii() {
	srun --time=0-05:00:00 --gres=gpu:$2 --partition=PGR-Standard -w damnii$1 --cpus-per-task=$3 --pty bash
}
