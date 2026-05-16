# dotfiles

Personal dotfiles manager for Arch Linux / i3 and macOS. Stores config copies
in this repo and syncs them to/from their real locations on the system.

## Structure

```
dotfiles/
├── config/        # mirrors ~/.config/  (Linux)
├── home/          # mirrors ~/          (Linux)
├── mac/
│   ├── config/    # mirrors ~/.config/  (macOS)
│   └── home/      # mirrors ~/          (macOS)
├── sync.sh        # CLI tool
└── manifest.conf  # list of tracked paths
```

## Usage

### Linux

```sh
# Copy live configs into the repo
./sync.sh collect

# Apply repo configs to the system
./sync.sh apply

# Show what differs between repo and system
./sync.sh status

# collect + commit + push to GitHub
./sync.sh push
```

### macOS

```sh
# Copy live configs into mac/
./sync.sh mac-collect

# Apply mac/ configs to the system
./sync.sh mac-apply
```

### Rollback

Each `collect`, `apply`, `mac-collect`, and `mac-apply` run saves a timestamped
backup under `.backup/`.

```sh
# Restore the most recent backup
./sync.sh rollback

# List all available backups
./sync.sh rollback list

# Restore latest backup for a specific label
./sync.sh rollback <label>

# Restore a specific snapshot
./sync.sh rollback <label> <timestamp>
```

Labels: `collect`, `apply`, `mac-collect`, `mac-apply`

## Adding a new config

Edit `manifest.conf`:
- Add a directory name under `[config]` to track `~/.config/<name>/` (Linux)
- Add a filename under `[home]` to track `~/<file>` (Linux)
- Use `[mac-config]` / `[mac-home]` for macOS equivalents

Then run `./sync.sh collect` (or `mac-collect` on macOS).

## Setup on a new machine

```sh
git clone <repo-url> ~/development/dotfiles
cd ~/development/dotfiles
./sync.sh apply        # Linux
# or
./sync.sh mac-apply    # macOS
```
