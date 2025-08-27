#!/usr/bin/env bash
# Usage: rotate_without_changing_layout.sh [cw|ccw]
# Rotate windows on the current space clockwise (cw) or counterclockwise (ccw)
# but instead of changing sizes entirely, just swap positions so the layout is preserved.
# This is useful when you want to keep a certain layout but make some windows bigger or smaller.
set -euo pipefail
DIR="${1:-cw}"   # cw (default) or ccw
# LOG=~/yabai-rotate.log
LOG=/dev/null
: > "$LOG"

echo "[info] direction=$DIR" >> "$LOG"

# 1) Query windows on this space
JSON="$(yabai -m query --windows --space 2>>"$LOG")" || exit 1

# Dump a compact inventory so you can see what fields exist
echo "[dbg] inventory:" >> "$LOG"
echo "$JSON" | jq -r 'map({id,app,"has-focus":."has-focus","is-visible":."is-visible",visible,floating,minimized,frame})' >> "$LOG"

# 2) Extract id + center coords (don’t filter on is-visible/floating until we know field names)
LINES="$(echo "$JSON" | jq -r '
  map(select(.id != null and .frame? != null)) |
  .[] | "\(.id)\t\((.frame.x + (.frame.w/2)))\t\((.frame.y + (.frame.h/2)))"
')"

# mapfile -t RAW <<<"$LINES"
RAW=()
while IFS=$'\t' read -r id cx cy; do
  RAW+=("$id $cx $cy")
done <<< "$LINES"

echo "[info] raw lines=${#RAW[@]}" >> "$LOG"
if (( ${#RAW[@]} <= 1 )); then
  echo "[info] <=1 usable window, exit" >> "$LOG"; exit 0
fi

# 3) Compute centroid
sx=0; sy=0; n=0
for line in "${RAW[@]}"; do
  read -r id cx cy <<<"$line"
  sx=$(awk -v a="$sx" -v b="$cx" 'BEGIN{print a+b}')
  sy=$(awk -v a="$sy" -v b="$cy" 'BEGIN{print a+b}')
  ((n++))
done
mx=$(awk -v s="$sx" -v n="$n" 'BEGIN{print s/n}')
my=$(awk -v s="$sy" -v n="$n" 'BEGIN{print s/n}')

# 4) Build list id+angle (flip Y so 0 rad = right, then increase CCW)
ORDER_LIST=()
for line in "${RAW[@]}"; do
  read -r id cx cy <<<"$line"
  # standardize geometry: dx to the right, dy upwards
  dx=$(awk -v x="$cx" -v mx="$mx" 'BEGIN{print x-mx}')
  dy=$(awk -v y="$cy" -v my="$my" 'BEGIN{print my-y}')  # NOTE: flipped Y
  ang=$(awk -v dx="$dx" -v dy="$dy" 'BEGIN{print atan2(dy, dx)}')   # [-pi, pi]

  # normalize to [0, 2pi) so rightmost = 0 rad
  ang2=$(awk -v a="$ang" 'BEGIN{if (a<0) a+=2*atan2(0,-1)*2/2; print a}')

  # For CW we want 0→2π (clockwise), which in screen coords is simply descending CCW.
  # So:
  key="$ang2"                 # CCW: sort ascending key
  [[ "$DIR" == "cw" ]] && key=$(awk -v a="$ang2" 'BEGIN{print (2*atan2(0,-1)*2/2)-a}')  # CW: reverse

  ORDER_LIST+=("$key $id")
done

IFS=$'\n' sorted=($(printf "%s\n" "${ORDER_LIST[@]}" | sort -k1,1n))
unset IFS
IDS=()
for entry in "${sorted[@]}"; do
  id="${entry##* }"
  [[ -n "$id" ]] && IDS+=("$id")
done

echo "[info] ordered ids: ${IDS[*]}" >> "$LOG"

if (( ${#IDS[@]} <= 1 )); then
  echo "[info] <=1 id after ordering; exit" >> "$LOG"; exit 0
fi

# 5) Rotate starting from the focused window
FOCUSED_ID=$(echo "$JSON" | jq -r 'map(select(."has-focus"==true))[0].id // empty')
if [[ -n "$FOCUSED_ID" ]]; then
  for i in "${!IDS[@]}"; do
    if [[ "${IDS[$i]}" == "$FOCUSED_ID" ]]; then
      IDS=( "${IDS[@]:$i}" "${IDS[@]:0:$i}" )
      break
    fi
  done
fi

FIRST="${IDS[0]}"
yabai -m window --focus "$FIRST" || true
for (( i=${#IDS[@]}-1; i>0; i-- )); do
  yabai -m window --swap "${IDS[$i]}" || echo "[warn] swap failed with ${IDS[$i]}" >> "$LOG"
done
yabai -m window --focus "$FIRST" || true
echo "[done]" >> "$LOG"
