#!/bin/bash

source "$HOME/.config/sketchybar/colors.sh"

WS="${NAME#space.}"

update_windows() {
  local strip=""
  local apps
  apps=$(aerospace list-windows --workspace "$WS" --json 2>/dev/null | jq -r '.[]."app-name"')
  if [ -n "$apps" ]; then
    while IFS= read -r app; do
      strip+=" $("$HOME/.config/sketchybar/plugins/icon_map.sh" "$app")"
    done <<< "$apps"
  fi
  sketchybar --set "$NAME" label="$strip"
}

update_highlight() {
  local focused="${FOCUSED_WORKSPACE:-$(aerospace list-workspaces --focused 2>/dev/null)}"
  local width="dynamic"
  local selected="off"
  if [ "$WS" = "$focused" ]; then
    width="0"
    selected="on"
  fi
  sketchybar --animate tanh 20 --set "$NAME" icon.highlight=$selected label.width=$width label.drawing=on
}

# AeroSpace prunes empty, unfocused, non-persistent workspaces from
# `list-workspaces --all`, so that list is exactly the set of workspaces
# actually in use. Hide the item for any workspace not in that set so the
# bar only ever shows workspaces that are actually being used.
update_visibility() {
  local used
  used=$(aerospace list-workspaces --all 2>/dev/null)
  if grep -qx "$WS" <<< "$used"; then
    sketchybar --set "$NAME" drawing=on
  else
    sketchybar --set "$NAME" drawing=off
  fi
}

mouse_clicked() {
  if [ "$BUTTON" = "right" ]; then
    aerospace move-node-to-workspace "$WS" >/dev/null 2>&1
    sketchybar --trigger aerospace_windows_changed
  else
    aerospace workspace "$WS" >/dev/null 2>&1
  fi
}

case "$SENDER" in
  "mouse.clicked") mouse_clicked
  ;;
  "aerospace_windows_changed") update_windows; update_visibility
  ;;
  *) update_windows; update_highlight; update_visibility
  ;;
esac
