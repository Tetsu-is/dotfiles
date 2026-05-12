#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="$SCRIPT_DIR/manifest.conf"
CONFIG_DIR="$SCRIPT_DIR/config"
HOME_DIR="$SCRIPT_DIR/home"
MAC_CONFIG_DIR="$SCRIPT_DIR/mac/config"
MAC_HOME_DIR="$SCRIPT_DIR/mac/home"

OS="$(uname -s)"

assert_linux() {
    if [[ "$OS" != "Linux" ]]; then
        echo "Error: '$1' is for Linux only. On macOS, use 'mac-apply' or 'mac-collect'." >&2
        exit 1
    fi
}

# Parse manifest and populate arrays
parse_manifest() {
    local section=""
    CONFIG_ENTRIES=()
    HOME_ENTRIES=()
    MAC_CONFIG_ENTRIES=()
    MAC_HOME_ENTRIES=()

    while IFS= read -r line; do
        # Strip comments and blank lines
        line="${line%%#*}"
        line="${line//[[:space:]]/}"
        [[ -z "$line" ]] && continue

        if [[ "$line" == "[config]" ]]; then
            section="config"
        elif [[ "$line" == "[home]" ]]; then
            section="home"
        elif [[ "$line" == "[mac-config]" ]]; then
            section="mac-config"
        elif [[ "$line" == "[mac-home]" ]]; then
            section="mac-home"
        elif [[ "$section" == "config" ]]; then
            CONFIG_ENTRIES+=("$line")
        elif [[ "$section" == "home" ]]; then
            HOME_ENTRIES+=("$line")
        elif [[ "$section" == "mac-config" ]]; then
            MAC_CONFIG_ENTRIES+=("$line")
        elif [[ "$section" == "mac-home" ]]; then
            MAC_HOME_ENTRIES+=("$line")
        fi
    done < "$MANIFEST"
}

cmd_collect() {
    assert_linux "collect"
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
    assert_linux "apply"
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
    assert_linux "status"
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
    assert_linux "push"
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

cmd_mac_collect() {
    if [[ "$OS" != "Darwin" ]]; then
        echo "Error: 'mac-collect' is for macOS only." >&2
        exit 1
    fi
    parse_manifest
    mkdir -p "$MAC_CONFIG_DIR" "$MAC_HOME_DIR"

    echo "==> Collecting mac/config/ entries..."
    for name in "${MAC_CONFIG_ENTRIES[@]+"${MAC_CONFIG_ENTRIES[@]}"}"; do
        src="$HOME/.config/$name"
        dst="$MAC_CONFIG_DIR/$name"
        if [[ -d "$src" ]]; then
            rm -rf "$dst"
            cp -a "$src" "$dst"
            echo "  collected: ~/.config/$name"
        else
            echo "  skipped (not found): ~/.config/$name"
        fi
    done

    echo "==> Collecting mac/home/ entries..."
    for file in "${MAC_HOME_ENTRIES[@]+"${MAC_HOME_ENTRIES[@]}"}"; do
        src="$HOME/$file"
        dst="$MAC_HOME_DIR/$file"
        if [[ -f "$src" ]]; then
            cp -a "$src" "$dst"
            echo "  collected: ~/$file"
        else
            echo "  skipped (not found): ~/$file"
        fi
    done

    echo "Done."
}

cmd_mac_apply() {
    if [[ "$OS" != "Darwin" ]]; then
        echo "Error: 'mac-apply' is for macOS only." >&2
        exit 1
    fi
    parse_manifest

    echo "==> Applying mac/config/ entries..."
    for name in "${MAC_CONFIG_ENTRIES[@]+"${MAC_CONFIG_ENTRIES[@]}"}"; do
        src="$MAC_CONFIG_DIR/$name"
        dst="$HOME/.config/$name"
        if [[ -d "$src" ]]; then
            rm -rf "$dst"
            cp -a "$src" "$dst"
            echo "  applied: ~/.config/$name"
        else
            echo "  skipped (not in repo): $name"
        fi
    done

    echo "==> Applying mac/home/ entries..."
    for file in "${MAC_HOME_ENTRIES[@]+"${MAC_HOME_ENTRIES[@]}"}"; do
        src="$MAC_HOME_DIR/$file"
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

usage() {
    cat <<EOF
Usage: sync.sh <command>

Linux commands:
  collect      Copy live config files into the repo  (Linux only)
  apply        Copy repo files out to system          (Linux only)
  status       Diff repo vs live files                (Linux only)
  push         collect + git commit + git push        (Linux only)

macOS commands:
  mac-collect  Copy live config files into mac/       (macOS only)
  mac-apply    Copy mac/ files out to system          (macOS only)
EOF
}

case "${1:-}" in
    collect)     cmd_collect ;;
    apply)       cmd_apply ;;
    status)      cmd_status ;;
    push)        cmd_push ;;
    mac-collect) cmd_mac_collect ;;
    mac-apply)   cmd_mac_apply ;;
    *)           usage; exit 1 ;;
esac
