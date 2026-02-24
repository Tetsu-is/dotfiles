# dotfiles

Personal dotfiles manager. Stores config copies in this repo and syncs them
to/from their real locations on the system.

## Structure

```
dotfiles/
├── config/        # mirrors ~/.config/
├── home/          # mirrors ~/
├── sync.sh        # CLI tool
└── manifest.conf  # list of tracked paths
```

## Usage

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

## Adding a new config

Edit `manifest.conf` and add a directory name under `[config]` or a filename
under `[home]`, then run `./sync.sh collect`.

## Setup on a new machine

```sh
git clone <repo-url> ~/development/dotfiles
cd ~/development/dotfiles
./sync.sh apply
```
