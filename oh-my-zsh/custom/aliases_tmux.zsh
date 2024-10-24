if [[ -n "$TMUX" ]]; then
	# get pwd of another pane (left, right, top, bottom)
	alias tpl='tmux display-message -p -F "#{pane_current_path}" -t left'
	alias tpr='tmux display-message -p -F "#{pane_current_path}" -t right'
	alias tpb='tmux display-message -p -F "#{pane_current_path}" -t bottom'
	alias tpt='tmux display-message -p -F "#{pane_current_path}" -t top'

	# send pwd or absolute file path to another pane
	function stp() {
		if [[ "$#" -eq 0 ]]; then
			echo "Usage: stp <left|right|top|bottom> [file_path (optional)]"
			return 1
	 	elif [[ "$#" -eq 1 ]]; then
			tmux send-keys -t $1 "$(pwd)"
		else
			tmux send-keys -t $1 "$(realpath "$2")"
		fi
	}
	alias stpl='stp left'
	alias stpr='stp right'
	alias stpb='stp bottom'
	alias stpt='stp top'

	function stpf() {
		if [[ "$#" -eq 0 ]]; then
			echo "Usage: stpf <left|right|top|bottom> [file_path (optional)]"
			return 1
		fi
		stp "$@"
		tmux select-pane -t $1
	}
	alias stpfl='stpf left'
	alias stpfr='stpf right'
	alias stpfb='stpf bottom'
	alias stpft='stpf top'

	# alias stpl='tmux send-keys -t left "$(pwd)"'
	# alias stpr='tmux send-keys -t right "$(pwd)"'
	# alias stpb='tmux send-keys -t bottom "$(pwd)"'
	# alias stpt='tmux send-keys -t top "$(pwd)"'

	# send pwd to another pane and focus (left, right, top, bottom)
	alias stplf='tmux send-keys -t left "$(pwd)"; tmux select-pane -t left'
	alias stprf='tmux send-keys -t right "$(pwd)"; tmux select-pane -t right'
	alias stpbf='tmux send-keys -t bottom "$(pwd)"; tmux select-pane -t bottom'
	alias stptf='tmux send-keys -t top "$(pwd)"; tmux select-pane -t top'

	# send pwd to another window (1, 2, 3, ...)
	function stw() {
		if [[ "$#" -eq 0 ]]; then
			echo "Usage: stw <window_number> [file_path (optional)]"
			return 1
		elif [[ "$#" -eq 1 ]]; then
			tmux send-keys -t $1. "$(pwd)"
		else
			tmux send-keys -t $1. "$(realpath "$2")"
		fi

	}
	
	# send pwd to another window and focus (1, 2, 3, ...)
	function stwf() {
		if [[ "$#" -eq 0 ]]; then
			echo "Usage: stwf <window_number> [file_path (optional)]"
			return 1
		fi
		stw "$@"
		tmux select-window -t $1.
	}
fi
