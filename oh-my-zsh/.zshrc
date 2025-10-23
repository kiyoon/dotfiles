SSH_ENV="$HOME/.ssh/agent.env"

start_agent() {
    echo "Starting new ssh-agent..."

	if [[ $OSTYPE == "darwin"* ]]; then
		ssh-agent -t 9h >| "$SSH_ENV"
	else
		ssh-agent -t 3h >| "$SSH_ENV"
	fi
    chmod 600 "$SSH_ENV"
    . "$SSH_ENV" > /dev/null
}

# If the file exists, source it and check if it's still valid
if [ -f "$SSH_ENV" ]; then
    . "$SSH_ENV" > /dev/null
	# it does not kill anything. Just checks if the agent is running
    if ! kill -0 "$SSH_AGENT_PID" 2>/dev/null; then
        # Agent dead; restart
        start_agent
    fi
else
    # No agent file yet
    start_agent
fi

# If you come from bash you might have to change your $PATH.
export BUN_INSTALL="$HOME/.bun"
export PATH="$HOME/bin:/usr/bin:/usr/local/bin:$PATH:$BUN_INSTALL/bin"

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
ZSH_CUSTOM="$HOME/.config/oh-my-zsh/custom"

# If you don't do this it will be initialised after everything.
# Can be a problem with custom mappings, like zsh-history-substring-search with Up/Down arrows.
ZVM_INIT_MODE=sourcing
# The plugin will auto execute this zvm_config function
# zvm_config() {
# 	if [[ $TERM == "wezterm" ]]; then
# 		# ZVM doesn't understand wezterm for cursor shape yet
# 		ZVM_TERM=xterm-256color
# 	fi
# }

ZVM_ESCAPE_KEYTIMEOUT=0.0
ZVM_KEYTIMEOUT=0.0

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
	cp						# cpv to rsync
	colored-man-pages
	colorize				# ccat
	docker
	encode64
	extract
	universalarchive		# ua tar.gz <file>
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

	# The below are implemented on my own (customised)
	# copypath
	# copyfile
	# copybuffer				# Ctrl+o to copy shell line
)

export DISABLE_VENV_CD=1  # disable virtualenvwrapper plugin to automatically activate on cd

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
bindkey '^s' autosuggest-accept

export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"


# source $ZSH/oh-my-zsh.sh
# bindkey '^[[A' history-substring-search-up
# bindkey '^[[B' history-substring-search-down

if (( $+commands[starship] )); then
	eval "$(starship init zsh)"
fi

# Auto activate conda or virtualenv when the current directory is a git repo with the same name as the conda env
# NOTE: This should be sourced at the end, so that other scripts don't override the conda env
git_root=$(git rev-parse --show-toplevel 2> /dev/null)
if [[ -n "$git_root" ]]; then
	basename_git_root=$(basename "$git_root")
	if [[ -d "$MINICONDA_PATH/envs/$basename_git_root" ]]; then
		# Before activating, deactivate any existing env
		while [[ -n "$VIRTUAL_ENV" ]]; do
			deactivate
		done
		while [[ -n "$CONDA_PREFIX" ]]; do
			conda deactivate
		done
		conda activate $basename_git_root
	fi
fi


autoload -Uz compinit
zstyle ':completion:*' menu select
fpath+=~/.zfunc

# WezTerm shell integration
# https://wezfurlong.org/wezterm/shell-integration.html
# However, OSC 133 previous and next commands are not working inside tmux.
# So, we disable semantic zones and use hard-wrapped prompt instead.
export WEZTERM_SHELL_SKIP_SEMANTIC_ZONES=1

# --- keep wezterm integration (cwd, vars, zones) ---
if [[ -r ~/.config/oh-my-zsh/wezterm.zsh ]]; then
  source ~/.config/oh-my-zsh/wezterm.zsh
fi

if [[ "$PROMPT" != *$'\e]133;A'* ]]; then
  # no gap between prompts
  # PROMPT=$'%{\e]133;A;cl=m;aid='$$'\a%}'"$PROMPT"$'%{\e]133;B\a%}'

  # start with new line
  PROMPT=$'%{\e]133;A;cl=m;aid='"$$"$'\a%}'"$PROMPT"$'%{\e]133;B\a%}'
fi

# Before each command, mark StartOutput
preexec() { printf '\e]133;C;\a'; }
