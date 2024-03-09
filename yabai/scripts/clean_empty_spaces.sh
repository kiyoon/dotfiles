#!/usr/bin/env bash

# https://github.com/koekeishiya/yabai/issues/213
# automatically remove empty spaces
yabai -m query --spaces --display | \
     jq -re 'map(select(."is-native-fullscreen" == false)) | length > 1' \
     && yabai -m query --spaces | \
          jq -re 'map(select(."windows" == [] and ."has-focus" == false).index) | reverse | .[] ' | \
          xargs -I % sh -c 'yabai -m space % --destroy'
