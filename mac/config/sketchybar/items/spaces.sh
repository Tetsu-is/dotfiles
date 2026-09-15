#!/bin/bash

# AeroSpace workspaces 1-9 (matches the alt-1..9 bindings in aerospace.toml).
# Unlike yabai, AeroSpace workspaces are not real macOS Spaces, so these are
# plain items (not the native `--add space` type) driven by the
# aerospace_workspace_change / aerospace_windows_changed events fired from
# aerospace.toml's exec-on-workspace-change / on-focus-changed callbacks.
#
# All 9 items are created up front, but plugins/space.sh hides (drawing=off)
# any workspace that AeroSpace doesn't currently report as in use, so only
# workspaces that are actually used ever show in the bar.

sid=0
for i in 1 2 3 4 5 6 7 8 9
do
  sid=$i

  space=(
    updates=on
    icon=$i
    icon.padding_left=10
    icon.padding_right=15
    padding_left=2
    padding_right=2
    label.padding_right=20
    icon.highlight_color=$RED
    label.font="sketchybar-app-font:Regular:16.0"
    label.background.height=26
    label.background.drawing=on
    label.background.color=$BACKGROUND_2
    label.background.corner_radius=8
    label.drawing=off
    drawing=off
    script="$PLUGIN_DIR/space.sh"
  )

  sketchybar --add item space.$sid left    \
             --set space.$sid "${space[@]}" \
             --subscribe space.$sid mouse.clicked aerospace_workspace_change aerospace_windows_changed
done

spaces=(
  background.color=$BACKGROUND_1
  background.border_color=$BACKGROUND_2
  background.border_width=2
  background.drawing=on
)

separator=(
  icon=􀆊
  icon.font="$FONT:Heavy:16.0"
  padding_left=15
  padding_right=15
  label.drawing=off
  associated_display=active
  icon.color=$WHITE
)

sketchybar --add bracket spaces '/space\..*/' \
           --set spaces "${spaces[@]}"        \
                                              \
           --add item separator left          \
           --set separator "${separator[@]}"
