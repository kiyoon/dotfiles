#!/bin/sh
# agent-sid.sh <pane_id> <pane_tty>
# Prints the running agent's session id for a pane, or nothing:
#   " cc:xxxxxxxx" Claude Code   " cx:xxxxxxxx" Codex
#   " gc:xxxxxxxx" Copilot CLI   " oc:xxxxxxxx" OpenCode
# The 8 chars come from the session id, taken from whichever end is random:
#   Claude Code: FIRST 8  (UUID v4, the head is random)   1911fd5f-4b6d-... -> cc:1911fd5f
#   Copilot:     FIRST 8  (UUID v4 as well)               a8c0e11e-4ea6-... -> gc:a8c0e11e
#   Codex:       LAST 8   (UUID v7; the head is a timestamp shared by sessions
#                          started the same minute, so it can't be used)
#   OpenCode:    LAST 8   (ses_<timestamp><random>, same reason)
# Resolve one back to its transcript with:
#   find ~/.claude/projects ~/.codex/sessions -name "*xxxxxxxx*.jsonl"
#   ls -d ~/.local/share/opencode/storage/*/ses_*xxxxxxxx*        # OpenCode
#   ls -d ~/.copilot/session-state/xxxxxxxx-*                     # Copilot
# tmux pane-border-format:  #(<dir>/agent-sid.sh #{pane_id} #{pane_tty})
# POSIX sh (dash/bash/zsh), macOS + Linux. No hooks: it reads what the agents leave behind.
pane=$1
tty=${2#/dev/}
claude_dir=${CLAUDE_CONFIG_DIR:-$HOME/.claude}
copilot_dir=${COPILOT_HOME:-$HOME/.copilot}
opencode_dir=${XDG_DATA_HOME:-$HOME/.local/share}/opencode
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

# The other three are found by locating their process on this pane's tty
# (macOS `comm` is a full path, Linux a bare name).
# `ps -t` is BSD + procps; busybox ps lacks it, so fall back to filtering the full list.
procs=$(ps -t "$tty" -o pid=,comm= 2>/dev/null) ||
  procs=$(ps -eo pid=,tty=,comm= 2>/dev/null | awk -v t="$tty" '$2 == t {print $1, $3}')
agent_pid() { printf '%s\n' "$procs" | awk -v n="$1" '$2 ~ "(^|/)" n "$" {print $1; exit}'; }

# Listing open files or scanning a log costs ~100 ms, so remember the answer per
# pid for 30 s. A just-started agent has no session yet, so keep an empty answer
# only 5 s and look again.
cached() {
  now=$(date +%s)
  cache=$cache_dir/$1.$2
  [ -f "$cache" ] || return 1
  read -r stamp result < "$cache"
  case $stamp in *[!0-9]*|'') stamp=0 ;; esac
  ttl=30; [ -z "$result" ] && ttl=5
  [ $((now - stamp)) -lt "$ttl" ] || return 1
  [ -n "$result" ] && printf ' %s' "$result"
  return 0
}
remember() {
  [ -d "$cache_dir" ] || mkdir -p "$cache_dir"
  find "$cache_dir" -type f -mmin +10 -delete 2>/dev/null   # entries of exited processes
  printf '%s %s\n' "$(date +%s)" "$3" > "$cache_dir/$1.$2"
  [ -n "$3" ] && printf ' %s' "$3"
}

# --- Codex -----------------------------------------------------------------
pid=$(agent_pid codex)
if [ -n "$pid" ]; then
  cached cx "$pid" && exit 0
  # Codex keeps its rollout file(s) open. Subagent threads have their own; take the newest main thread.
  if [ -d "/proc/$pid/fd" ]; then                 # Linux
    files=$(for l in /proc/"$pid"/fd/*; do readlink "$l"; done 2>/dev/null)
  else                                            # macOS
    files=$(lsof -n -P -F n -p "$pid" 2>/dev/null | sed -n 's/^n//p')
  fi
  result=$(printf '%s\n' "$files" | grep '/rollout-.*\.jsonl$' | sort -r | while read -r f; do
    head -n 1 "$f" | grep -q '"subagent"' && continue
    id=${f%.jsonl}; id=${id##*-}                  # last UUID group (12 hex, the random part of a v7)
    printf 'cx:%s' "$(printf %s "$id" | cut -c5-12)"  # -> last 8 hex of the UUID
    break
  done)
  remember cx "$pid" "$result"
  exit 0
fi

# --- Copilot CLI -----------------------------------------------------------
# Copilot writes one log per process and puts the pid in its name
# (logs/process-<start_ms>-<pid>.log), so the pane-to-session link is exact.
# The log records "Registering foreground session: <uuid>" and the matching
# "Unregistering ..." when it closes; the one still open is the live session.
pid=$(agent_pid copilot)
if [ -n "$pid" ]; then
  cached gc "$pid" && exit 0
  log=$(ls -t "$copilot_dir"/logs/process-*-"$pid".log 2>/dev/null | head -n 1)
  result=
  if [ -n "$log" ]; then
    sid=$(awk '
      # "Unregistering" contains "Registering", so it has to be tested first.
      /Unregistering foreground session: /{ n=split($0,a,": "); delete open[a[n]]; next }
      /Registering foreground session: /  { n=split($0,a,": "); open[a[n]]=NR }
      END { best=""; rank=0; for (k in open) if (open[k] > rank) { rank=open[k]; best=k }; print best }
    ' "$log")
    [ -n "$sid" ] && result="gc:$(printf %s "$sid" | cut -c1-8)"   # first 8 hex of the UUID
  fi
  remember gc "$pid" "$result"
  exit 0
fi

# --- OpenCode --------------------------------------------------------------
# OpenCode gives a pane nothing to go on: every instance shares one database
# and one log, and neither records a pid. The only honest discriminator left is
# when the process started -- the shared log opens each instance with
# "creating instance directory=<cwd>" within a second or two of it. Matching on
# the directory alone is NOT enough: a later instance in the same directory
# would win and show the wrong session. So both must agree, and an ambiguous
# match prints nothing rather than a guess.
pid=$(agent_pid opencode)
[ -n "$pid" ] || exit 0
cached oc "$pid" && exit 0

log=$opencode_dir/log/opencode.log
result=
if [ -f "$log" ]; then
  if [ -d "/proc/$pid" ]; then                    # Linux
    cwd=$(readlink "/proc/$pid/cwd" 2>/dev/null)
  else                                            # macOS
    cwd=$(lsof -a -p "$pid" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p' | head -n 1)
  fi
  # elapsed time is "[[dd-]hh:]mm:ss" on both BSD and procps
  elapsed=$(ps -p "$pid" -o etime= 2>/dev/null | awk '
    { gsub(/ /,""); d=0; split($0,p,"-"); t=$0
      if (p[2] != "") { d=p[1]; t=p[2] }
      n=split(t,c,":")
      s=(n==3) ? c[1]*3600+c[2]*60+c[3] : c[1]*60+c[2]
      print d*86400+s }')
  if [ -n "$cwd" ] && [ -n "$elapsed" ]; then
    started=$(( $(date +%s) - elapsed ))
    # One pass over the shared log (it is megabytes and still growing):
    # find the run whose start matches, then keep that run's latest session id.
    result=$(awk -v cwd="$cwd" -v started="$started" '
      # The log stamps UTC ISO times; turn one into an epoch without needing date(1).
      function epoch(s,   y,mo,d,h,mi,se,days,i,md) {
        y=substr(s,1,4)+0; mo=substr(s,6,2)+0; d=substr(s,9,2)+0
        h=substr(s,12,2)+0; mi=substr(s,15,2)+0; se=substr(s,18,2)+0
        for (i=1970; i<y; i++) days += (i%4==0 && (i%100!=0 || i%400==0)) ? 366 : 365
        split("31 28 31 30 31 30 31 31 30 31 30 31", md, " ")
        for (i=1; i<mo; i++) { days += md[i]; if (i==2 && (y%4==0 && (y%100!=0 || y%400==0))) days++ }
        return ((( days + d-1 )*24 + h)*60 + mi)*60 + se
      }
      index($0, "creating instance") && index($0, "directory=" cwd) {
        ts=substr($0, index($0,"timestamp=")+10, 20)
        gap = epoch(ts) - started; if (gap < 0) gap = -gap
        if (gap <= 10) {
          match($0, /run=[a-f0-9]+/); r=substr($0, RSTART+4, RLENGTH-4)
          if (!(r in seen)) { seen[r]=1; hits++; pick=r }
        }
      }
      pick != "" && index($0, "run=" pick) && match($0, /session\.id=ses_[A-Za-z0-9]+/) {
        sid=substr($0, RSTART+14, RLENGTH-14)
      }
      END {
        # two instances started in the same directory at the same moment: refuse
        if (hits == 1 && sid != "") printf "oc:%s", substr(sid, length(sid)-7)
      }
    ' "$log")
  fi
fi
remember oc "$pid" "$result"
