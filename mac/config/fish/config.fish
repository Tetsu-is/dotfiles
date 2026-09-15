if status is-interactive

    # PATH
    fish_add_path /opt/homebrew/bin /opt/homebrew/sbin # Homebrew
    fish_add_path /usr/local/go/bin ~/go/bin # Go
    set -gx VOLTA_HOME ~/.volta
    fish_add_path $VOLTA_HOME/bin # Volta (Node.js)
    fish_add_path ~/.cargo/bin # Rust
    fish_add_path ~/.local/bin # Local binaries (claude, uv, uvx)

    # Google Cloud SDK
    if test -f ~/google-cloud-sdk/path.fish.inc
        source ~/google-cloud-sdk/path.fish.inc
    end

    # Starship prompt
    set -gx STARSHIP_CONFIG ~/.config/starship/starship.toml
    starship init fish | source

    # Git abbreviations
    abbr -a ga 'git add'
    abbr -a gcm 'git commit -m'
    abbr -a gps 'git push'
    abbr -a gpl 'git pull'
    abbr -a gsw 'git switch'
    abbr -a gswc 'git switch -c'
    abbr -a gwt 'git worktree'
    abbr -a gwtl 'git worktree list'
    abbr -a gwtp 'git worktree prune'

    # claude abbreviations
    abbr -a cl claude
    abbr -a clr 'claude --resume'

    # kitty abbreviations
    abbr -a kitty-reload 'kitty @ load-config'

end

# bun
set --export BUN_INSTALL "$HOME/.bun"
set --export PATH $BUN_INSTALL/bin $PATH
