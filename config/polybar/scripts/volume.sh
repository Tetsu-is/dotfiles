#!/usr/bin/env bash
# Manage volume of the currently active audio sink (PipeWire/wpctl).
# Usage: volume.sh          – print current volume (for polybar)
#        volume.sh 10%+     – raise volume
#        volume.sh 10%-     – lower volume
#        volume.sh mute     – toggle mute

status=$(wpctl status 2>/dev/null)

# Find the name of the sink currently receiving active streams
sink_name=$(echo "$status" | awk '
    /Streams:/ { in_streams=1 }
    in_streams && /\[active\]/ {
        gsub(/.*> /, ""); gsub(/:.*/, ""); print; exit
    }
')

# Map sink name -> numeric ID
if [ -n "$sink_name" ]; then
  sink_id=$(echo "$status" | awk -v name="$sink_name" '
        /Sinks:/ { in_sinks=1 }
        /Sources:|Filters:|Streams:/ { in_sinks=0 }
        in_sinks && index($0, name) {
            gsub(/[^0-9 ]/, "")
            for (i=1; i<=NF; i++) if ($i+0 > 0) { print $i; exit }
        }
    ')
fi

sink="${sink_id:-@DEFAULT_AUDIO_SINK@}"

_xob_notify() {
  out=$(wpctl get-volume "$sink" 2>/dev/null)
  if echo "$out" | grep -q "MUTED"; then
    vol=0
  else
    vol=$(echo "$out" | awk '{v = int($2 * 100); print (v > 100 ? 100 : v)}')
  fi

  # Bar dimensions: length=200, border=12, padding=2, thickness=8
  # total_w=224 half=112; total_h=36 half=18
  read -r mx my mw mh < <(i3-msg -t get_workspaces 2>/dev/null |
    jq -r '.[] | select(.focused) | "\(.rect.x) \(.rect.y) \(.rect.width) \(.rect.height)"')
  xob_x=$((mx + mw / 2 - 112))
  xob_y=$((my + 15))

  mkfifo /tmp/xobpipe 2>/dev/null

  # Restart xob only if not running or focused monitor changed
  if ! pgrep -x xob >/dev/null || ! grep -q "offset = ${xob_x};" /tmp/xob_current.cfg 2>/dev/null; then
    # Load colors from colorctl current theme
    theme_file="${HOME}/.config/colorctl/themes/$(cat "${HOME}/.config/colorctl/current" 2>/dev/null)"
    if [ -f "$theme_file" ]; then
      # shellcheck source=/dev/null
      source "$theme_file"
    fi
    bg="${CC_THEME_BACKGROUND:-#000000}"
    fg_normal="${CC_THEME_PRIMARY:-#ffffff}"
    fg_alt="${CC_THEME_COMMENT:-#888888}"
    fg_overflow="${CC_THEME_ORANGE:-#ff9f0a}"
    fg_altoverflow="${CC_THEME_ALERT:-#ff5555}"

    cat >/tmp/xob_current.cfg <<EOF
default = {
    x = {relative = 0.0; offset = ${xob_x};};
    y = {relative = 0.0; offset = ${xob_y};};
    @include "${HOME}/.config/xob/styles.cfg"
    color = {
        normal      = { fg = "${fg_normal}"; bg = "${bg}"; border = "${fg_normal}"; };
        alt         = { fg = "${fg_alt}";    bg = "${bg}"; border = "${bg}"; };
        overflow    = { fg = "${fg_overflow}";    bg = "${bg}"; border = "${bg}"; };
        altoverflow = { fg = "${fg_altoverflow}"; bg = "${bg}"; border = "${bg}"; };
    };
};
EOF
    pkill xob 2>/dev/null
    sleep 0.05
    nohup bash -c 'tail -f /tmp/xobpipe | xob -c /tmp/xob_current.cfg' >/dev/null 2>&1 &
  fi

  echo "$vol" >/tmp/xobpipe
}

_polybar_notify() {
  [ -p /tmp/volpipe ] || return
  out=$(wpctl get-volume "$sink" 2>/dev/null)
  if echo "$out" | grep -q "MUTED"; then
    echo "MUTED" >/tmp/volpipe
  else
    vol=$(echo "$out" | awk '{printf "%d", $2 * 100}')
    echo "${vol}%" >/tmp/volpipe
  fi
}

case "$1" in
mute)
  wpctl set-mute "$sink" toggle
  _polybar_notify
  _xob_notify
  ;;
"")
  out=$(wpctl get-volume "$sink" 2>/dev/null)
  if echo "$out" | grep -q "MUTED"; then
    echo "MUTED"
  else
    vol=$(echo "$out" | awk '{printf "%d", $2 * 100}')
    echo "${vol}%"
  fi
  ;;
*)
  wpctl set-volume "$sink" "$1"
  _polybar_notify
  _xob_notify
  ;;
esac
