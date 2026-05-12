if status is-interactive

    # Homebrew
    fish_add_path /opt/homebrew/bin /opt/homebrew/sbin

    # Go
    fish_add_path /usr/local/go/bin ~/go/bin

    # Volta (Node.js)
    set -gx VOLTA_HOME ~/.volta
    fish_add_path $VOLTA_HOME/bin

    # Local binaries (claude, uv, uvx)
    fish_add_path ~/.local/bin

    # Google Cloud SDK
    source ~/google-cloud-sdk/path.fish.inc

    # Starship prompt
    starship init fish | source

    # Git abbreviations
    abbr -a ga   'git add'
    abbr -a gcm  'git commit -m'
    abbr -a gps  'git push'
    abbr -a gpl  'git pull'
    abbr -a gsw  'git switch'
    abbr -a gswc 'git switch -c'
    abbr -a gwt  'git worktree'

end
