export DOTFILES_DIR="$(dotfiles_dir)"

alias dust-filter="uv run $(dotfiles_dir)/oh-my-zsh/scripts/dust_utils.py"
alias gdust="bash $(dotfiles_dir)/oh-my-zsh/scripts/gdust.sh"
alias gdusts="bash $(dotfiles_dir)/oh-my-zsh/scripts/gdust.sh --staged"
alias gdusth="bash $(dotfiles_dir)/oh-my-zsh/scripts/gdust.sh --head"
alias gdustd="bash $(dotfiles_dir)/oh-my-zsh/scripts/gdust.sh --dirty"
alias webpify="uv run $(dotfiles_dir)/oh-my-zsh/scripts/webpify.py"
alias archive-code="uv run $(dotfiles_dir)/oh-my-zsh/scripts/archive_code.py"
alias agent-usage="uv run $(dotfiles_dir)/oh-my-zsh/scripts/agent-usage.py"

cache-clean() {
	bash "$DOTFILES_DIR/oh-my-zsh/scripts/cache-clean.sh" "$@"
}
