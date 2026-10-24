# Installer

`install.sh` checks dependencies, clones or updates the shell, writes the default config, sets up autostart, and handles `--import` and `--uninstall`. It is tested by `tests/test_install.py`.

## Rules

- Every change it makes goes through `act`, so `--dry-run` stays accurate. A new step uses it too.
- It runs `sudo` only after a typed yes.
- It never overwrites the config files.

## What it links and undoes

- It links `scripts/island_run.py` as `~/.local/bin/island-run`. The script finds its imports through `realpath`, so it works from the link. `--uninstall` removes the link only when it points into the install.
- `--uninstall` runs `scripts/kde_colors.py restore`, so a KDE colour scheme applied by the shell is undone (see `KDE_THEME.md`).
