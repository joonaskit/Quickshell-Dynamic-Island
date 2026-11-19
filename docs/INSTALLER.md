# Installer

`install.sh` checks dependencies, clones or updates the shell, writes the default config, sets up autostart, and handles `--import` and `--uninstall`. It is tested by `tests/test_install.py`.

## Rules

- Every change it makes goes through `act`, so `--dry-run` stays accurate. A new step uses it too.
- It runs `sudo` only after a typed yes.
- It never overwrites the config files. They live in `~/.config/quickshell-island/` (or `$ISLAND_CONFIG_DIR`), apart from the install; files an older version left in the install folder are moved there first, as `run.sh` does (`docs/SETTINGS.md`).

## What it links and undoes

- It links `scripts/island_run.py` as `~/.local/bin/island-run`. The script finds its imports through `realpath`, so it works from the link. `--uninstall` removes the link only when it points into the install.
- `--uninstall` removes the install folder and asks, defaulting to no, whether to delete the config files too. An emptied config folder is removed with them; `theme.json` stays.
- `--uninstall` runs `scripts/kde_colors.py restore`, so a KDE colour scheme applied by the shell is undone (see `KDE_THEME.md`).
