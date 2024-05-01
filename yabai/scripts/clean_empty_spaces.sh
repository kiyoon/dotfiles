#!/usr/bin/env bash

# https://github.com/koekeishiya/yabai/issues/213
# automatically remove empty spaces

# When exiting YouTube fullscreen, the space gets deleted.
# This is a workaround to prevent that from happening.

yabai -m query --spaces --display | \
  jq -re 'all(."is-native-fullscreen" | not)' &> /dev/null || exit; \

hidden_windows=$(yabai -m query --windows | jq 'map(select(."is-hidden")) | map(."id")'); \

yabai -m query --spaces | \
  jq -re "map(select((.\"has-focus\" | not) and (\
    .\"windows\" | map(select(. as \$window | $hidden_windows | index(\$window) | not))\
    ) == []).index) | reverse | .[]" | \
  xargs -I % sh -c 'yabai -m space % --destroy'

# yabai -m query --spaces --display | \
#      jq -re 'map(select(."is-native-fullscreen" == false)) | length > 1' \
#      && yabai -m query --spaces | \
#           jq -re 'map(select(."windows" == []).index) | reverse | .[] ' | \
#           xargs -I % sh -c 'yabai -m space % --destroy'

          # jq -re 'map(select(."windows" == [] and ."has-focus" == false).index) | reverse | .[] ' | \
