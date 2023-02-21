# If you come from bash you might have to change your $PATH.
export PATH=$HOME/bin:/usr/local/bin:$PATH

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="robbyrussell"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
HIST_STAMPS="yyyy-mm-dd"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM="$HOME/.config/dotfiles/oh-my-zsh/custom"

# If you don't do this it will be initialised after everything.
# Can be a problem with custom mappings, like zsh-history-substring-search with Up/Down arrows.
ZVM_INIT_MODE=sourcing

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(
	fzf-tab
	git-open
	zsh-vi-mode
	# vi-mode
	zsh-autosuggestions
	# zsh-syntax-highlighting
	fast-syntax-highlighting
	zsh-history-substring-search
	conda-zsh-completion
	web-search				# google, ddg, ...
	copypath
	copyfile
	copybuffer				# Ctrl+o to copy shell line
	cp						# cpv to rsync
	colored-man-pages
	colorize				# ccat
	docker
	encode64
	extract
	fancy-ctrl-z			# Ctrl+z again to fg
	dirhistory				# Alt+Left/Right/Up to navigate dir history
	jsontools				# pp_json
	tmux					# ta to attach to tmux session, ts to create new session
	gitignore				# gi python >> .gitignore
	git						# gst, ga, gc to status, add, and commit
	tig						# tis: tig status
	gh
	fzf
	zoxide
	thefuck
	ripgrep
)

# VI_MODE_RESET_PROMPT_ON_MODE_CHANGE=false
# VI_MODE_SET_CURSOR=true

# Must set this before ZVM is sourced. (i.e. before oh-my-zsh.sh)
# It will be overridden by custom/env.zsh
export EDITOR='nvim'
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='TERM=wezterm nvim'
# else
#   export EDITOR='TERM=wezterm nvim'
# fi

source $ZSH/oh-my-zsh.sh

# User configuration

bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down

export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Compilation flags
export ARCHFLAGS="-arch x86_64"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$("$HOME/bin/miniconda3/bin/conda" 'shell.zsh' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "$HOME/bin/miniconda3/etc/profile.d/conda.sh" ]; then
        . "$HOME/bin/miniconda3/etc/profile.d/conda.sh"
    else
        export PATH="$HOME/bin/miniconda3/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<
#

# source $ZSH/oh-my-zsh.sh
# bindkey '^[[A' history-substring-search-up
# bindkey '^[[B' history-substring-search-down

if (( $+commands[starship] )); then
	eval "$(starship init zsh)"
fi
