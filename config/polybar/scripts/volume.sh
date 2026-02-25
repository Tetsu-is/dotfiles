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

case "$1" in
mute)
  wpctl set-mute "$sink" toggle
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
  ;;
esac
