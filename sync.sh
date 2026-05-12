#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="$SCRIPT_DIR/manifest.conf"
CONFIG_DIR="$SCRIPT_DIR/config"
HOME_DIR="$SCRIPT_DIR/home"
MAC_CONFIG_DIR="$SCRIPT_DIR/mac/config"
MAC_HOME_DIR="$SCRIPT_DIR/mac/home"
BACKUP_ROOT="$SCRIPT_DIR/.backup"

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

# Create a timestamped backup of given source paths under .backup/<label>/<timestamp>/
# Usage: make_backup <label> <src>...
make_backup() {
    local label="$1"; shift
    local timestamp
    timestamp="$(date +%Y%m%d_%H%M%S)"
    local backup_dir="$BACKUP_ROOT/$label/$timestamp"
    mkdir -p "$backup_dir"

    local backed_up=0
    for src in "$@"; do
        if [[ -e "$src" ]]; then
            cp -a "$src" "$backup_dir/"
            backed_up=1
        fi
    done

    if [[ $backed_up -eq 1 ]]; then
        echo "  backup: $backup_dir"
        echo "$backup_dir"  # return path for rollback reference
    else
        rmdir "$backup_dir"
        echo ""
    fi
}

cmd_collect() {
    assert_linux "collect"
    parse_manifest
    mkdir -p "$CONFIG_DIR" "$HOME_DIR"

    echo "==> Backing up repo config/ and home/..."
    local srcs=()
    for name in "${CONFIG_ENTRIES[@]}"; do
        [[ -d "$CONFIG_DIR/$name" ]] && srcs+=("$CONFIG_DIR/$name")
    done
    for file in "${HOME_ENTRIES[@]}"; do
        [[ -f "$HOME_DIR/$file" ]] && srcs+=("$HOME_DIR/$file")
    done
    if [[ ${#srcs[@]} -gt 0 ]]; then
        make_backup "collect" "${srcs[@]}" > /dev/null
    fi

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

    echo "==> Backing up live config/ and home/ entries..."
    local srcs=()
    for name in "${CONFIG_ENTRIES[@]}"; do
        [[ -d "$HOME/.config/$name" ]] && srcs+=("$HOME/.config/$name")
    done
    for file in "${HOME_ENTRIES[@]}"; do
        [[ -f "$HOME/$file" ]] && srcs+=("$HOME/$file")
    done
    if [[ ${#srcs[@]} -gt 0 ]]; then
        make_backup "apply" "${srcs[@]}" > /dev/null
    fi

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

    echo "==> Backing up mac/config/ and mac/home/..."
    local srcs=()
    for name in "${MAC_CONFIG_ENTRIES[@]+"${MAC_CONFIG_ENTRIES[@]}"}"; do
        [[ -d "$MAC_CONFIG_DIR/$name" ]] && srcs+=("$MAC_CONFIG_DIR/$name")
    done
    for file in "${MAC_HOME_ENTRIES[@]+"${MAC_HOME_ENTRIES[@]}"}"; do
        [[ -f "$MAC_HOME_DIR/$file" ]] && srcs+=("$MAC_HOME_DIR/$file")
    done
    if [[ ${#srcs[@]} -gt 0 ]]; then
        make_backup "mac-collect" "${srcs[@]}" > /dev/null
    fi

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

    echo "==> Backing up live mac config entries..."
    local srcs=()
    for name in "${MAC_CONFIG_ENTRIES[@]+"${MAC_CONFIG_ENTRIES[@]}"}"; do
        [[ -d "$HOME/.config/$name" ]] && srcs+=("$HOME/.config/$name")
    done
    for file in "${MAC_HOME_ENTRIES[@]+"${MAC_HOME_ENTRIES[@]}"}"; do
        [[ -f "$HOME/$file" ]] && srcs+=("$HOME/$file")
    done
    if [[ ${#srcs[@]} -gt 0 ]]; then
        make_backup "mac-apply" "${srcs[@]}" > /dev/null
    fi

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

# rollback [list|<label>] [<timestamp>]
# Without args: restore latest backup across all labels
# list: show available backups
# <label>: restore latest backup for that label
# <label> <timestamp>: restore specific snapshot
cmd_rollback() {
    local subcmd="${1:-latest}"
    shift || true

    if [[ "$subcmd" == "list" ]]; then
        if [[ ! -d "$BACKUP_ROOT" ]]; then
            echo "No backups found."
            return
        fi
        echo "Available backups:"
        for label_dir in "$BACKUP_ROOT"/*/; do
            local label
            label="$(basename "$label_dir")"
            for snap in "$label_dir"*/; do
                [[ -d "$snap" ]] && echo "  $label  $(basename "$snap")"
            done
        done
        return
    fi

    local label timestamp snap

    if [[ "$subcmd" == "latest" ]]; then
        # Find the single most recent snapshot across all labels
        if [[ ! -d "$BACKUP_ROOT" ]]; then
            echo "No backups found." >&2; exit 1
        fi
        snap="$(find "$BACKUP_ROOT" -mindepth 2 -maxdepth 2 -type d | sort | tail -1)"
        if [[ -z "$snap" ]]; then
            echo "No backups found." >&2; exit 1
        fi
        label="$(basename "$(dirname "$snap")")"
        timestamp="$(basename "$snap")"
    else
        label="$subcmd"
        timestamp="${1:-}"
        if [[ -z "$timestamp" ]]; then
            snap="$(find "$BACKUP_ROOT/$label" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort | tail -1)"
            if [[ -z "$snap" ]]; then
                echo "No backups found for label '$label'." >&2; exit 1
            fi
            timestamp="$(basename "$snap")"
        fi
        snap="$BACKUP_ROOT/$label/$timestamp"
        if [[ ! -d "$snap" ]]; then
            echo "Backup not found: $snap" >&2; exit 1
        fi
    fi

    echo "==> Restoring from backup: $label/$timestamp"

    for item in "$snap"/*/; do
        [[ -d "$item" ]] || continue
        name="$(basename "$item")"

        # Determine destination based on label
        case "$label" in
            collect)
                dst_config="$CONFIG_DIR/$name"
                dst_home="$HOME_DIR/$name"
                if [[ -d "$dst_config" || ! -d "$dst_home" ]]; then
                    rm -rf "$dst_config"
                    cp -a "$item" "$dst_config"
                    echo "  restored (repo): config/$name"
                else
                    rm -rf "$dst_home"
                    cp -a "$item" "$dst_home"
                    echo "  restored (repo): home/$name"
                fi
                ;;
            apply)
                dst="$HOME/.config/$name"
                rm -rf "$dst"
                cp -a "$item" "$dst"
                echo "  restored (system): ~/.config/$name"
                ;;
            mac-collect)
                dst="$MAC_CONFIG_DIR/$name"
                rm -rf "$dst"
                cp -a "$item" "$dst"
                echo "  restored (repo): mac/config/$name"
                ;;
            mac-apply)
                dst="$HOME/.config/$name"
                rm -rf "$dst"
                cp -a "$item" "$dst"
                echo "  restored (system): ~/.config/$name"
                ;;
            *)
                echo "  unknown label '$label', skipping $name" >&2
                ;;
        esac
    done

    # Restore plain files (home/ entries like .zshrc)
    for item in "$snap"/.*  "$snap"/*; do
        [[ -f "$item" ]] || continue
        name="$(basename "$item")"
        case "$label" in
            collect)
                cp "$item" "$HOME_DIR/$name"
                echo "  restored (repo): home/$name"
                ;;
            apply|mac-apply)
                cp "$item" "$HOME/$name"
                echo "  restored (system): ~/$name"
                ;;
            mac-collect)
                cp "$item" "$MAC_HOME_DIR/$name"
                echo "  restored (repo): mac/home/$name"
                ;;
        esac
    done

    echo "Done."
}

usage() {
    cat <<EOF
Usage: sync.sh <command>

Linux commands:
  collect                Copy live config files into the repo  (Linux only)
  apply                  Copy repo files out to system          (Linux only)
  status                 Diff repo vs live files                (Linux only)
  push                   collect + git commit + git push        (Linux only)

macOS commands:
  mac-collect            Copy live config files into mac/       (macOS only)
  mac-apply              Copy mac/ files out to system          (macOS only)

Rollback:
  rollback               Restore the most recent backup
  rollback list          List all available backups
  rollback <label>       Restore latest backup for <label>
  rollback <label> <ts>  Restore specific snapshot

  Labels: collect, apply, mac-collect, mac-apply
EOF
}

case "${1:-}" in
    collect)     cmd_collect ;;
    apply)       cmd_apply ;;
    status)      cmd_status ;;
    push)        cmd_push ;;
    mac-collect) cmd_mac_collect ;;
    mac-apply)   cmd_mac_apply ;;
    rollback)    shift; cmd_rollback "$@" ;;
    *)           usage; exit 1 ;;
esac
