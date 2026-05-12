#!/bin/sh

WORKSPACE_ID="$1"

if [ -z "$FOCUSED_WORKSPACE" ]; then
  FOCUSED_WORKSPACE="$(aerospace list-workspaces --focused 2>/dev/null)"
fi

ALL_WORKSPACES="$(aerospace list-workspaces --all 2>/dev/null)"

if echo "$ALL_WORKSPACES" | grep -qx "$WORKSPACE_ID"; then
  drawing=on
else
  drawing=off
fi

if [ "$FOCUSED_WORKSPACE" = "$WORKSPACE_ID" ]; then
  sketchybar --set "$NAME" drawing="$drawing" background.drawing=on label.color=0xff000000
else
  sketchybar --set "$NAME" drawing="$drawing" background.drawing=off label.color=0xffffffff
fi
