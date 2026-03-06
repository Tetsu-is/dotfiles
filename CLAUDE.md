# dotfiles

Personal dotfiles manager for Arch Linux / i3 setup.

## Structure

```
dotfiles/
├── config/        # mirrors ~/.config/
├── home/          # mirrors ~/
├── sync.sh        # CLI tool
└── manifest.conf  # list of tracked paths
```

## Git Worktree Workflow

For every task, use a git worktree to isolate changes:

```sh
# Create a worktree in the PARENT directory (never inside the repo)
git worktree add ../dotfiles-<task-name> -b <task-name>

# Work inside the worktree
cd ../dotfiles-<task-name>

# When done, merge/PR and clean up
git worktree remove ../dotfiles-<task-name>
```

Use the `EnterWorktree` tool when available to set up the worktree automatically.

### Worktree rules
- Always create worktrees in the **parent directory** (`../dotfiles-<task-name>`)
- Naming: `dotfiles-{branch-name}`
- Never create worktrees inside `.claude/`, `.git/`, or any subdirectory of the repo
- Add `.worktrees/` and `.claude/` to `.gitignore` to avoid accidentally committing them
- Remove the worktree after merging

## Workflows

```sh
./sync.sh collect   # copy live configs into repo
./sync.sh apply     # copy repo configs out to system
./sync.sh status    # diff repo vs live files
./sync.sh push      # collect + git commit + git push
```

## Adding a new config

Edit `manifest.conf`:
- Add a directory name under `[config]` to track `~/.config/<name>/`
- Add a filename under `[home]` to track `~/<file>`

Then run `./sync.sh collect`.

## Tracked configs

| Entry | Live path |
|---|---|
| nvim | ~/.config/nvim (LazyVim) |
| kitty | ~/.config/kitty |
| i3 | ~/.config/i3 |
| polybar | ~/.config/polybar |
| rofi | ~/.config/rofi |
| starship | ~/.config/starship |
| picom | ~/.config/picom |
| cava | ~/.config/cava |
| zsh-abbr | ~/.config/zsh-abbr |
| autorandr | ~/.config/autorandr |
| .zshrc | ~/.zshrc |
| .gitconfig | ~/.gitconfig |

## Stack

- WM: i3 (`$mod` = Super)
- Bar: polybar (launches via `~/.config/polybar/launch.sh`)
- Terminal: kitty
- Editor: neovim (LazyVim)
- Launcher: rofi (`Alt+Space`)
- Compositor: picom
- Theme: Dracula (managed by colorctl — `~/.config/colorctl/i3.conf` included in i3 config)
- Font: JetBrainsMono
- Wallpaper: feh (`~/Downloads/arch-dracula.png`)
- Lock screen: betterlockscreen (`$mod+Shift+Escape`)
- Input method: fcitx5
- Shell: zsh with starship prompt and zsh-abbr

## Notes

- colorctl manages theme colors; i3 and polybar both pull from `~/.config/colorctl/`
- polybar scripts live in `config/polybar/scripts/` — `volume.sh` handles audio sink switching and signals polybar on change
- `sync.sh push` auto-commits with message `sync: YYYY-MM-DD`
