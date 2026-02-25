#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="$SCRIPT_DIR/manifest.conf"
CONFIG_DIR="$SCRIPT_DIR/config"
HOME_DIR="$SCRIPT_DIR/home"

# Parse manifest and populate arrays
parse_manifest() {
    local section=""
    CONFIG_ENTRIES=()
    HOME_ENTRIES=()

    while IFS= read -r line; do
        # Strip comments and blank lines
        line="${line%%#*}"
        line="${line//[[:space:]]/}"
        [[ -z "$line" ]] && continue

        if [[ "$line" == "[config]" ]]; then
            section="config"
        elif [[ "$line" == "[home]" ]]; then
            section="home"
        elif [[ "$section" == "config" ]]; then
            CONFIG_ENTRIES+=("$line")
        elif [[ "$section" == "home" ]]; then
            HOME_ENTRIES+=("$line")
        fi
    done < "$MANIFEST"
}

cmd_collect() {
    parse_manifest
    mkdir -p "$CONFIG_DIR" "$HOME_DIR"

    echo "==> Collecting config/ entries..."
    for name in "${CONFIG_ENTRIES[@]}"; do
        src="$HOME/.config/$name"
        dst="$CONFIG_DIR/$name"
        if [[ -d "$src" ]]; then
            rm -rf "$dst"
            cp -a "$src" "$dst"
            echo "  collected: ~/.config/$name"
        else
            echo "  skipped (not found): ~/.config/$name"
        fi
    done

    echo "==> Collecting home/ entries..."
    for file in "${HOME_ENTRIES[@]}"; do
        src="$HOME/$file"
        dst="$HOME_DIR/$file"
        if [[ -f "$src" ]]; then
            cp -a "$src" "$dst"
            echo "  collected: ~/$file"
        else
            echo "  skipped (not found): ~/$file"
        fi
    done

    echo "Done."
}

cmd_apply() {
    parse_manifest

    echo "==> Applying config/ entries..."
    for name in "${CONFIG_ENTRIES[@]}"; do
        src="$CONFIG_DIR/$name"
        dst="$HOME/.config/$name"
        if [[ -d "$src" ]]; then
            rm -rf "$dst"
            cp -a "$src" "$dst"
            echo "  applied: ~/.config/$name"
        else
            echo "  skipped (not in repo): $name"
        fi
    done

    echo "==> Applying home/ entries..."
    for file in "${HOME_ENTRIES[@]}"; do
        src="$HOME_DIR/$file"
        dst="$HOME/$file"
        if [[ -f "$src" ]]; then
            cp "$src" "$dst"
            echo "  applied: ~/$file"
        else
            echo "  skipped (not in repo): $file"
        fi
    done

    echo "Done."
}

cmd_status() {
    parse_manifest
    local diffs=0

    echo "==> Checking config/ entries..."
    for name in "${CONFIG_ENTRIES[@]}"; do
        repo="$CONFIG_DIR/$name"
        live="$HOME/.config/$name"
        if [[ ! -d "$repo" ]]; then
            echo "  [not collected] $name"
        elif [[ ! -d "$live" ]]; then
            echo "  [missing on system] ~/.config/$name"
        else
            result=$(diff -rq "$repo" "$live" 2>&1 || true)
            if [[ -n "$result" ]]; then
                echo "  [differs] ~/.config/$name"
                diff --color=always -ru "$repo" "$live" 2>&1 | sed 's/^/    /' || true
                ((diffs++)) || true
            else
                echo "  [ok] ~/.config/$name"
            fi
        fi
    done

    echo "==> Checking home/ entries..."
    for file in "${HOME_ENTRIES[@]}"; do
        repo="$HOME_DIR/$file"
        live="$HOME/$file"
        if [[ ! -f "$repo" ]]; then
            echo "  [not collected] $file"
        elif [[ ! -f "$live" ]]; then
            echo "  [missing on system] ~/$file"
        else
            result=$(diff -q "$repo" "$live" 2>&1 || true)
            if [[ -n "$result" ]]; then
                echo "  [differs] ~/$file"
                diff --color=always -u "$repo" "$live" 2>&1 | sed 's/^/    /' || true
                ((diffs++)) || true
            else
                echo "  [ok] ~/$file"
            fi
        fi
    done

    if [[ $diffs -gt 0 ]]; then
        echo ""
        echo "$diffs file(s) differ between repo and system."
    else
        echo ""
        echo "All tracked files are in sync."
    fi
}

cmd_push() {
    cmd_collect

    cd "$SCRIPT_DIR"
    git add -A
    if git diff --cached --quiet; then
        echo "Nothing to commit — repo is already up to date."
    else
        git commit -m "sync: $(date +%Y-%m-%d)"
        git push
        echo "Pushed to remote."
    fi
}

usage() {
    cat <<EOF
Usage: sync.sh <command>

Commands:
  collect   Copy live config files into the repo
  apply     Copy repo files out to system locations
  status    Show diff between repo and live files
  push      collect + git commit + git push
EOF
}

case "${1:-}" in
    collect) cmd_collect ;;
    apply)   cmd_apply ;;
    status)  cmd_status ;;
    push)    cmd_push ;;
    *)       usage; exit 1 ;;
esac
