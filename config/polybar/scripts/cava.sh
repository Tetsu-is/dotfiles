#!/usr/bin/env bash
# Launch cava pointed at whichever sink is currently running.
# Automatically restarts if the active sink changes (device switch).

CONF="${XDG_CONFIG_HOME:-$HOME/.config}/cava/config"

active_monitor() {
    pactl list sources short 2>/dev/null \
        | awk '/RUNNING/ && /\.monitor/ { print $2; exit }'
}

run_cava() {
    local source tmpconf
    source=$(active_monitor)
    [ -z "$source" ] && source="auto"

    tmpconf=$(mktemp --suffix=.conf /tmp/cava.XXXXXX)
    sed "s|^source = .*|source = $source|" "$CONF" > "$tmpconf"
    cava -p "$tmpconf"
    rm -f "$tmpconf"
}

# Re-run whenever cava exits (device switch causes cava to error-exit).
# A clean quit (user presses 'q', exit 0) breaks the loop.
while true; do
    run_cava
    [[ $? -eq 0 ]] && break
    sleep 0.5
done
