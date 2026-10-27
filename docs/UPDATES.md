# Updates

The "Check for updates" button on the About page. `UpdateService` runs `scripts/update_check.py`, which does the git work; its pure logic (release order, what a state means) is in `scripts/update_core.py`. Tests: `tests/test_update_core.py`, and `tests/test_update_check.py` on temporary repositories.

It only runs when the button is pressed.

## Channels

The `updateChannel` setting:

- **stable** (the default): the newest release tag, `vX.Y.Z` or `vX.Y.Z-alpha|beta|rc.N`. A plain release sorts after its pre-releases. Commits after the latest release are not offered.
- **beta**: the newest commit on `origin/main`.

A checkout that is already past the target, for example a beta install that switches back to stable, is up to date. It is never moved back.

## Rules

- The fetch never waits for a password or a host question, and gives up after 60 seconds, as in `install.sh`.
- Updates only fast-forward the `main` branch (`git merge --ff-only`), so the checkout stays on `main` and either channel can carry on from it.
- Nothing is changed when the checkout is on another branch (a developer checkout), has edited tracked files, has commits that are not upstream, or is not its own git checkout (a copied install, or a folder inside another repository).
- After an update the shell must be restarted. "Restart the shell" runs `run.sh -d`, as the autostart entry does. The tool check runs again, since an update can need a new tool.

`install.sh` run again still updates with `git pull --ff-only`, whatever the channel.
