#!/usr/bin/env bash
# Quickshell Island installer: checks the system, installs the shell, creates the
# default configuration and sets up autostart. Safe to run again: it updates the
# shell and never overwrites your configuration.
#
#   ./install.sh [options]
#
# Run it from a checkout. If that checkout is already in the install folder the
# shell is updated in place, otherwise it is cloned there.

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DEFAULT_REMOTE="https://github.com/joonaskit/Quickshell-Dynamic-Island.git"
CONFIG_FILES=(settings.json dock_pinned.json launcher_usage.json)
EXAMPLE_FILES=(settings.json dock_pinned.json)

PREFIX="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/island"
AUTOSTART_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/autostart/quickshell-island.desktop"
# island-run: a link to scripts/island_run.py (see docs/ACTIVITIES_API.md), on the usual per-user PATH
LINK_FILE="${XDG_BIN_HOME:-$HOME/.local/bin}/island-run"
DEPS=1
AUTOSTART=1
LINK=1
ASSUME_YES=0
DRY_RUN=0
UNINSTALL=0
IMPORT_FILE=""

usage() {
    cat <<'EOF'
Usage: ./install.sh [options]

  --prefix <dir>     Install in <dir> (default: ~/.config/quickshell/island)
  --no-deps          Do not offer to install missing packages
  --no-autostart     Do not start the shell at login
  --no-link          Do not add the island-run command to ~/.local/bin
  --import <file>    Load a configuration exported with ./run.sh --export
  --yes              Do not ask questions, accept the defaults (packages are
                     then never installed: the command is only shown)
  --dry-run          Show what would happen and change nothing
  --uninstall        Remove the autostart entry, the island-run link and the
                     install folder
  -h, --help         Show this help
EOF
}

say() { printf '%s\n' "$*"; }
note() { printf '  %s\n' "$*"; }
die() { printf 'Error: %s\n' "$*" >&2; exit 1; }

# Asks a yes/no question, with the answer to use when Enter is pressed or --yes is given
ask() {
    local question="$1" default="$2" reply hint="[y/N]"
    [ "$default" = y ] && hint="[Y/n]"
    if [ "$ASSUME_YES" = 1 ]; then
        [ "$default" = y ]
        return
    fi
    if [ ! -t 0 ]; then
        die "\"$question\" needs an answer, and there is no terminal. Run it in a terminal or add --yes."
    fi
    read -r -p "$question $hint " reply
    case "${reply:-$default}" in
        y|Y|yes|YES) return 0 ;;
        *) return 1 ;;
    esac
}

# Runs a command that changes the system, or only prints it with --dry-run
act() {
    if [ "$DRY_RUN" = 1 ]; then
        note "would run: $*"
        return 0
    fi
    "$@"
}

# Refuses folders that could hold anything but this shell, before anything is deleted
is_shell_dir() {
    [ -n "$1" ] && [ "$1" != "/" ] && [ "$1" != "$HOME" ] && [ -f "$1/shell.qml" ] && [ -f "$1/run.sh" ] && [ -f "$1/qmldir" ]
}

# True when a folder holds nothing but configuration files, as after an uninstall that kept them
holds_only_config() {
    local entry name
    for entry in "$1"/* "$1"/.[!.]*; do
        [ -e "$entry" ] || continue
        name="$(basename "$entry")"
        case " ${CONFIG_FILES[*]} " in
            *" $name "*) ;;
            *) return 1 ;;
        esac
    done
}

# ---------------------------------------------------------------------------

check_environment() {
    say "Checking the environment"
    command -v python3 >/dev/null 2>&1 || die "python3 was not found. Install Python 3 first, then run this again."
    command -v git >/dev/null 2>&1 || [ -d "$PREFIX" ] || note "git was not found. The shell will be copied instead of cloned, and cannot update itself."
    if [ "${XDG_SESSION_TYPE:-}" != "wayland" ]; then
        note "This session is '${XDG_SESSION_TYPE:-unknown}', not Wayland. The shell only works in a Plasma Wayland session, so the check below may fail until you log in to one."
    fi
}

# Runs the dependency check, and offers the install command for what is missing
check_dependencies() {
    local checker="$SRC/scripts/check_deps.py" report
    say "Checking dependencies"
    python3 "$checker" | sed 's/^/  /'
    report="$(python3 "$checker" --json)"
    local command
    command="$(printf '%s' "$report" | python3 -c 'import json,sys; print(json.load(sys.stdin)["installCommand"])')"

    if [ "$DEPS" = 1 ] && [ -n "$command" ]; then
        say ""
        say "The missing packages can be installed with:"
        note "$command"
        if [ "$DRY_RUN" = 1 ]; then
            note "would ask whether to run it"
        elif ask "Run it now? It uses sudo and may ask for your password." n; then
            sh -c "$command" || note "The installation did not finish. Fix that and run this again."
            say "Checking again"
            python3 "$checker" | sed 's/^/  /'
        fi
    fi

    if ! python3 "$checker" --json | python3 -c 'import json,sys; sys.exit(0 if json.load(sys.stdin)["ok"] else 1)'; then
        say ""
        [ "$DRY_RUN" = 1 ] || die "Something the shell cannot run without is missing (see REQUIRED above). Install it and run this again."
        note "Something required is missing. A real run would stop here."
    fi
}

install_shell() {
    say "Installing the shell in $PREFIX"
    if [ "$SRC" = "$PREFIX" ]; then
        note "This checkout is the install folder."
        update_checkout
        return
    fi
    local kept=""
    if [ -e "$PREFIX" ]; then
        if is_shell_dir "$PREFIX"; then
            update_checkout
            return
        fi
        holds_only_config "$PREFIX" || die "$PREFIX exists and is not a Quickshell Island install. Pick another folder with --prefix."
        # What an uninstall that kept the configuration leaves behind: set it aside, and put it back
        note "Found the configuration of an earlier install, and keeping it."
        if [ "$DRY_RUN" != 1 ]; then
            kept="$(mktemp -d)"
            mv "$PREFIX"/* "$PREFIX"/.[!.]* "$kept"/ 2>/dev/null
            rmdir "$PREFIX"
        fi
    fi
    act mkdir -p "$(dirname "$PREFIX")"
    if [ -d "$SRC/.git" ] && command -v git >/dev/null 2>&1; then
        local remote
        remote="$(git -C "$SRC" remote get-url origin 2>/dev/null || true)"
        act git clone --quiet "$SRC" "$PREFIX"
        # Updates then come from the real repository, not from this checkout
        act git -C "$PREFIX" remote set-url origin "${remote:-$DEFAULT_REMOTE}"
    else
        act mkdir -p "$PREFIX"
        act cp -a "$SRC/." "$PREFIX/"
        note "Copied, since there is no git checkout to clone."
        # Never take another machine's configuration along with the files
        local name
        for name in "${CONFIG_FILES[@]}"; do act rm -f "${PREFIX:?}/$name"; done
    fi
    if [ -n "$kept" ]; then
        mv "$kept"/* "$kept"/.[!.]* "$PREFIX"/ 2>/dev/null
        rmdir "$kept"
    fi
}

# Brings an existing install up to date, leaving anything you changed alone
update_checkout() {
    [ -d "$PREFIX/.git" ] && command -v git >/dev/null 2>&1 || { note "Not a git checkout, so there is nothing to update."; return; }
    if [ -n "$(git -C "$PREFIX" status --porcelain --untracked-files=no)" ]; then
        note "There are local changes in the shell's files, so it is not updated."
        return
    fi
    # Never wait for a password or a host question: a failed update is only a note
    act env GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND="ssh -o BatchMode=yes" timeout 60 git -C "$PREFIX" pull --ff-only --quiet || note "Could not update (no network, or the history has diverged). Carrying on with what is installed."
}

import_configuration() {
    [ -n "$IMPORT_FILE" ] || return 0
    say "Importing $IMPORT_FILE"
    [ -f "$IMPORT_FILE" ] || die "The file $IMPORT_FILE does not exist."
    if [ "$DRY_RUN" = 1 ]; then
        note "would import it with scripts/settings_backup.py"
        return
    fi
    python3 "$PREFIX/scripts/settings_backup.py" import "$IMPORT_FILE" --dir "$PREFIX" | sed 's/^/  /'
    [ "${PIPESTATUS[0]}" = 0 ] || die "The import failed, nothing was changed. Fix the file or run this again without --import."
}

# Copies the .example files for whatever configuration does not exist yet
create_default_configuration() {
    say "Configuration"
    local name path
    for name in "${EXAMPLE_FILES[@]}"; do
        path="$PREFIX/$name"
        if [ -e "$path" ]; then
            note "$name already exists, left as it is."
        else
            act cp "$PREFIX/$name.example" "$path"
            [ "$DRY_RUN" = 1 ] || note "Created $name from $name.example."
        fi
    done
}

setup_autostart() {
    [ "$AUTOSTART" = 1 ] || { say "Autostart skipped"; return; }
    say "Autostart"
    if [ -e "$AUTOSTART_FILE" ] && grep -q "^Exec=$PREFIX/run.sh -d\$" "$AUTOSTART_FILE" 2>/dev/null; then
        note "Already set up."
        return
    fi
    if [ "$DRY_RUN" = 1 ]; then
        note "would write $AUTOSTART_FILE"
        return
    fi
    mkdir -p "$(dirname "$AUTOSTART_FILE")"
    cat > "$AUTOSTART_FILE" <<EOF
[Desktop Entry]
Type=Application
Name=Quickshell Island
Comment=Island bar and dock for KDE Plasma
Exec=$PREFIX/run.sh -d
Icon=preferences-desktop-theme
Terminal=false
X-GNOME-Autostart-enabled=true
EOF
    note "Wrote $AUTOSTART_FILE"
}

# island-run shows any command's progress in the island. A file that is not our link is left alone
setup_command() {
    [ "$LINK" = 1 ] || { say "island-run skipped"; return; }
    say "island-run command"
    local target="$PREFIX/scripts/island_run.py"
    if [ -L "$LINK_FILE" ] && [ "$(readlink "$LINK_FILE")" = "$target" ]; then
        note "Already set up."
        return
    fi
    if [ -e "$LINK_FILE" ] || [ -L "$LINK_FILE" ]; then
        note "$LINK_FILE already exists and is not ours, so it is left alone."
        return
    fi
    act mkdir -p "$(dirname "$LINK_FILE")"
    act ln -s "$target" "$LINK_FILE"
    [ "$DRY_RUN" = 1 ] || note "Linked $LINK_FILE."
    case ":$PATH:" in
        *":$(dirname "$LINK_FILE"):"*) ;;
        *) note "$(dirname "$LINK_FILE") is not in your PATH. Add it to run island-run by name." ;;
    esac
}

print_summary() {
    say ""
    say "Done."
    [ "$DRY_RUN" = 1 ] && say "(Dry run: nothing was changed.)"
    note "Start it now:       $PREFIX/run.sh"
    note "Check the system:   $PREFIX/run.sh --check"
    [ "$LINK" = 1 ] && note "Show a command in the island: island-run <command>"
    note "Update later:       run $PREFIX/install.sh again"
    note "Remove it:          $PREFIX/install.sh --uninstall"
    [ "$AUTOSTART" = 1 ] && note "It starts at your next login."
    note "The welcome guide opens the first time the shell starts."
}

uninstall() {
    say "Uninstalling"
    if [ -e "$AUTOSTART_FILE" ]; then
        act rm -f "$AUTOSTART_FILE"
        note "Removed the autostart entry."
    fi
    # Only a link that points into this install is ours to remove
    if [ -L "$LINK_FILE" ] && [ "$(readlink "$LINK_FILE")" = "$PREFIX/scripts/island_run.py" ]; then
        act rm -f "$LINK_FILE"
        note "Removed the island-run link."
    fi
    if [ ! -e "$PREFIX" ]; then
        note "There is no install in $PREFIX."
        return
    fi
    is_shell_dir "$PREFIX" || die "$PREFIX is not a Quickshell Island install, so it is left alone."
    if [ -x "$PREFIX/run.sh" ]; then
        act "$PREFIX/run.sh" -k >/dev/null 2>&1 || true
    fi
    # Puts back the KDE colour scheme from before the "Apply to KDE Apps" setting, if it is on
    if [ -f "$PREFIX/scripts/kde_colors.py" ] && command -v python3 >/dev/null; then
        act python3 "$PREFIX/scripts/kde_colors.py" restore >/dev/null 2>&1 || true
    fi

    local name kept=()
    for name in "${CONFIG_FILES[@]}"; do
        [ -e "$PREFIX/$name" ] && kept+=("$name")
    done
    if [ ${#kept[@]} -gt 0 ] && ! ask "Also delete your configuration (${kept[*]})?" n; then
        # Everything but the configuration goes
        local tmp
        if [ "$DRY_RUN" = 1 ]; then
            note "would remove everything in $PREFIX except ${kept[*]}"
        else
            tmp="$(mktemp -d)"
            for name in "${kept[@]}"; do mv "$PREFIX/$name" "$tmp/"; done
            rm -rf "$PREFIX"
            mkdir -p "$PREFIX"
            for name in "${kept[@]}"; do mv "$tmp/$name" "$PREFIX/"; done
            rmdir "$tmp"
        fi
        note "Removed the shell. Your configuration is still in $PREFIX."
        return
    fi
    act rm -rf "$PREFIX"
    note "Removed $PREFIX."
}

main() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --prefix) [ -n "${2:-}" ] || die "--prefix needs a folder."; PREFIX="$(realpath -m "$2")"; shift ;;
            --import) [ -n "${2:-}" ] || die "--import needs a file."; IMPORT_FILE="$(realpath -m "$2")"; shift ;;
            --no-deps) DEPS=0 ;;
            --no-autostart) AUTOSTART=0 ;;
            --no-link) LINK=0 ;;
            --yes|-y) ASSUME_YES=1 ;;
            --dry-run) DRY_RUN=1 ;;
            --uninstall) UNINSTALL=1 ;;
            -h|--help) usage; exit 0 ;;
            *) usage >&2; die "Unknown option: $1" ;;
        esac
        shift
    done

    [ "$DRY_RUN" = 1 ] && say "Dry run: nothing will be changed."
    if [ "$UNINSTALL" = 1 ]; then
        uninstall
        return
    fi

    check_environment
    check_dependencies
    install_shell
    import_configuration
    create_default_configuration
    setup_autostart
    setup_command
    print_summary
}

# The script is read to the end of main before it runs, so updating the checkout
# this file lives in cannot change what is executing
main "$@"
exit $?
