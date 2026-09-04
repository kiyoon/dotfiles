#!/bin/sh
# agent-sid.sh <pane_id> <pane_tty>
# Prints " cc:xxxxxxxx" for a pane running Claude Code, " cx:xxxxxxxx" for Codex, nothing otherwise.
# The 8 hex chars come from the session UUID:
#   Claude Code: the FIRST 8  (UUID v4, the head is random)      1911fd5f-4b6d-4844-bcf3-ce3a917a3ec4 -> cc:1911fd5f
#   Codex:       the LAST 8   (UUID v7, the head is a timestamp   01a05beb-5f71-75f2-baae-f5ee26b43ff5 -> cx:26b43ff5
#                              shared by sessions started the same minute, so it can't be used)
# Either resolves back to its transcript with:
#   find ~/.claude/projects ~/.codex/sessions -name "*xxxxxxxx*.jsonl"
# tmux pane-border-format:  #(<dir>/agent-sid.sh #{pane_id} #{pane_tty})
# POSIX sh (dash/bash/zsh), macOS + Linux. No hooks: it reads what the agents leave behind.
pane=$1
tty=${2#/dev/}
claude_dir=${CLAUDE_CONFIG_DIR:-$HOME/.claude}
cache_dir=${XDG_CACHE_HOME:-$HOME/.cache}/agent-sid

# Claude Code registers every interactive session in <claude_dir>/sessions/<pid>.json,
# and the entry names the tmux pane it runs in:  "tmux":"session:@window.%pane"
for f in "$claude_dir"/sessions/*.json; do
  [ -f "$f" ] || continue
  grep -q "\\.$pane\"" "$f" 2>/dev/null || continue
  pid=${f##*/}; pid=${pid%.json}
  kill -0 "$pid" 2>/dev/null || continue          # stale file left by a crashed session
  sid=$(sed -n 's/.*"sessionId":"\([0-9a-f]\{8\}\).*/\1/p' "$f")   # first 8 hex of the UUID
  [ -n "$sid" ] && { printf ' cc:%s' "$sid"; exit 0; }
done

# Codex: find the codex process on this pane's tty (macOS `comm` is a full path, Linux a bare name).
# `ps -t` is BSD + procps; busybox ps lacks it, so fall back to filtering the full list.
procs=$(ps -t "$tty" -o pid=,comm= 2>/dev/null) ||
  procs=$(ps -eo pid=,tty=,comm= 2>/dev/null | awk -v t="$tty" '$2 == t {print $1, $3}')
pid=$(printf '%s\n' "$procs" | awk '$2 ~ /(^|\/)codex$/ {print $1; exit}')
[ -n "$pid" ] || exit 0

# Listing open files costs ~100 ms on macOS, so remember the answer per pid for 30 s.
# A fresh Codex TUI has no thread until its first message, so an empty answer is only kept 5 s.
now=$(date +%s)
cache=$cache_dir/cx.$pid
if [ -f "$cache" ]; then
  read -r stamp result < "$cache"
  case $stamp in *[!0-9]*|'') stamp=0 ;; esac
  ttl=30; [ -z "$result" ] && ttl=5
  [ $((now - stamp)) -lt "$ttl" ] && { [ -n "$result" ] && printf ' %s' "$result"; exit 0; }
fi

# Codex keeps its rollout file(s) open. Subagent threads have their own; take the newest main thread.
if [ -d "/proc/$pid/fd" ]; then                   # Linux
  files=$(for l in /proc/"$pid"/fd/*; do readlink "$l"; done 2>/dev/null)
else                                              # macOS
  files=$(lsof -n -P -F n -p "$pid" 2>/dev/null | sed -n 's/^n//p')
fi
result=$(printf '%s\n' "$files" | grep '/rollout-.*\.jsonl$' | sort -r | while read -r f; do
  head -n 1 "$f" | grep -q '"subagent"' && continue
  id=${f%.jsonl}; id=${id##*-}                    # last UUID group (12 hex, the random part of a v7)
  printf 'cx:%s' "$(printf %s "$id" | cut -c5-12)"  # -> last 8 hex of the UUID
  break
done)
[ -d "$cache_dir" ] || mkdir -p "$cache_dir"
find "$cache_dir" -type f -mmin +10 -delete 2>/dev/null   # entries of exited processes
printf '%s %s\n' "$now" "$result" > "$cache"
[ -n "$result" ] && printf ' %s' "$result"
