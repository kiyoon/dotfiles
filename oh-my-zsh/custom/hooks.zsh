if [[ -n $TMUX_PLUGIN_MANAGER_PATH ]]; then
	tmux-window-name() {
		(/usr/bin/python3 $TMUX_PLUGIN_MANAGER_PATH/tmux-window-name/scripts/rename_session_windows.py &)
	}

	add-zsh-hook chpwd tmux-window-name
fi
