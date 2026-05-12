#!/bin/sh

FOCUSED="${FOCUSED_WORKSPACE:-$(aerospace list-workspaces --focused 2>/dev/null)}"
ALL="$(aerospace list-workspaces --all 2>/dev/null)"

# Add items for new workspaces (errors if already exists — that's fine)
for ws in $ALL; do
  sketchybar --add item space.$ws left 2>/dev/null || true
done

# Remove items for destroyed workspaces
for i in 1 2 3 4 5 6 7 8 9; do
  if ! echo "$ALL" | grep -qx "$i"; then
    sketchybar --remove space.$i 2>/dev/null || true
  fi
done

# Update highlight for all current workspaces (always runs, separate from --add)
for ws in $ALL; do
  if [ "$ws" = "$FOCUSED" ]; then
    sketchybar --set space.$ws \
                      label="$ws" \
                      icon.padding_left=7 \
                      icon.padding_right=7 \
                      background.color=0x40ffffff \
                      background.corner_radius=5 \
                      background.height=25 \
                      background.drawing=on \
                      label.color=0xff000000
  else
    sketchybar --set space.$ws \
                      label="$ws" \
                      icon.padding_left=7 \
                      icon.padding_right=7 \
                      background.color=0x40ffffff \
                      background.corner_radius=5 \
                      background.height=25 \
                      background.drawing=off \
                      label.color=0xffffffff
  fi
done

# Keep workspace items at the far left, before front_app
SPACE_ITEMS=""
for ws in $ALL; do
  SPACE_ITEMS="$SPACE_ITEMS space.$ws"
done
sketchybar --reorder $SPACE_ITEMS front_app 2>/dev/null || true
