#!/usr/bin/env bash
# Cava visualizer for polybar.
# Reads raw ASCII bar values from cava and maps them to block characters.
# Dynamically detects the active audio monitor (handles Bluetooth switches).

CONF="${XDG_CONFIG_HOME:-$HOME/.config}/cava/polybar"
chars=(' ' '▁' '▂' '▃' '▄' '▅' '▆' '▇' '█')

active_monitor() {
    pactl list sources short 2>/dev/null \
        | awk '/RUNNING/ && /\.monitor/ { print $2; exit }'
}

run_cava() {
    local source tmpconf
    source=$(active_monitor)
    [ -z "$source" ] && source="auto"

    tmpconf=$(mktemp --suffix=.conf /tmp/cava_polybar.XXXXXX)
    sed "s|^source = .*|source = $source|" "$CONF" > "$tmpconf"

    cava -p "$tmpconf" | while IFS=';' read -ra values; do
        out=""
        for v in "${values[@]}"; do
            out+="${chars[$v]:-█}"
        done
        printf '%s\n' "$out"
    done

    rm -f "$tmpconf"
}

# Restart cava when it exits (e.g. on device switch).
# Clean quit (exit 0) breaks the loop.
while true; do
    run_cava
    [[ $? -eq 0 ]] && break
    sleep 0.5
done
