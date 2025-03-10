#!/usr/bin/env bash

# Get the next window id in the current session.
# e.g. @1, @2, @3, ...

current_id=$(tmux display-message -p '#{window_id}')
window_list=$(tmux list-windows -F '#{window_id}')

next_window_id=$(echo "$window_list" | grep -A1 "$current_id" | tail -1)

if [ "$current_id" == "$next_window_id" ]; then
    next_window_id=$(echo "$window_list" | head -1)
fi

echo "$next_window_id"
