#!/usr/bin/env bash

# Get the prev window id in the current session.
# e.g. @1, @2, @3, ...

current_id=$(tmux display-message -p '#{window_id}')
window_list=$(tmux list-windows -F '#{window_id}')

prev_window_id=$(echo "$window_list" | grep -B1 "$current_id" | head -1)

if [ "$current_id" == "$prev_window_id" ]; then
    prev_window_id=$(echo "$window_list" | tail -1)
fi

echo "$prev_window_id"
