if [[ -n $TMUX_PLUGIN_MANAGER_PATH ]]; then
	tmux-window-name() {
		/usr/bin/python3 \
			"$TMUX_PLUGIN_MANAGER_PATH/tmux-window-name/scripts/rename_session_windows.py" &!
	}

	_tmux-window-name-preexec() {
		# $2 is alias-expanded, so cod/cld become codex/claude here.
		case ${${(z)2}[1]:t} in
			claude|codex) ;;
			*) return 0 ;;
		esac

		typeset -g _tmux_window_name_reset=1

		# Wait until the foreground child exists before asking the plugin to scan it.
		(
			sleep 0.5
			exec /usr/bin/python3 \
				"$TMUX_PLUGIN_MANAGER_PATH/tmux-window-name/scripts/rename_session_windows.py"
		) &!
	}

	_tmux-window-name-precmd() {
		[[ -n ${_tmux_window_name_reset:-} ]] || return 0

		unset _tmux_window_name_reset
		tmux-window-name
		return 0
	}

	add-zsh-hook chpwd tmux-window-name
	add-zsh-hook preexec _tmux-window-name-preexec
	add-zsh-hook precmd _tmux-window-name-precmd
fi
