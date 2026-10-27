#!/usr/bin/env python3
"""Check for updates to the shell, and apply one. Run by UpdateService.

Usage:
  update_check.py check --channel stable|beta [--dir <path>]
  update_check.py update --channel stable|beta [--dir <path>]

Prints one line of JSON:
  {"ok", "state", "channel", "current", "target", "behind", "commits", "canUpdate", "error"}

`state` is one of the states in update_core.decide, or:
  no-git      git is not installed
  not-git     the shell folder is not its own git checkout (a copied install)
  no-target   nothing to update to: no release tag (stable) or no origin/main (beta)
  offline     the fetch failed (no network, or the remote asks for a password)
  updated     an update was applied (update only)
  failed      git refused the update; `error` says why

The fetch never waits for a password or a host question, as in install.sh.
The channels and the rules are in docs/UPDATES.md.
"""
import argparse
import json
import os
import subprocess
import sys

from update_core import BRANCH, CHANNELS, decide, latest_release

SHELL_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
FETCH_TIMEOUT = 60
# The subjects listed for an update; the count is always the full one
MAX_COMMITS = 20

GIT_ENV = dict(os.environ, GIT_TERMINAL_PROMPT="0", GIT_SSH_COMMAND="ssh -o BatchMode=yes", LC_ALL="C")


class GitError(Exception):
    pass


def git(directory, *args, timeout=15):
    """The stripped output of a git command. Raises GitError with git's last line on failure."""
    try:
        result = subprocess.run(["git", "-C", directory, *args], capture_output=True, text=True,
                                env=GIT_ENV, timeout=timeout, check=False)
    except subprocess.TimeoutExpired as e:
        raise GitError("git %s took too long" % args[0]) from e
    if result.returncode != 0:
        lines = result.stderr.strip().splitlines()
        raise GitError(lines[-1] if lines else "git %s failed" % args[0])
    return result.stdout.strip()


def is_own_checkout(directory):
    """True when `directory` is the top of a git checkout, not a folder inside another one."""
    try:
        top = git(directory, "rev-parse", "--show-toplevel")
    except GitError:
        return False
    return os.path.realpath(top) == os.path.realpath(directory)


def commit_of(directory, ref):
    """The commit `ref` points at, or None when there is no such ref."""
    try:
        return git(directory, "rev-parse", "--verify", "--quiet", ref + "^{commit}")
    except GitError:
        return None


def resolve_target(directory, channel):
    """(label, commit) of what the channel would update to; the commit is None when there is nothing."""
    if channel == "beta":
        return "origin/" + BRANCH, commit_of(directory, "refs/remotes/origin/" + BRANCH)
    tag = latest_release(git(directory, "tag", "--list", "v*").splitlines())
    if tag is None:
        return None, None
    return tag, commit_of(directory, "refs/tags/" + tag)


def check(directory, channel):
    """The result of a check, as a dict. Fetches from origin first."""
    result = {"ok": True, "channel": channel, "current": "", "target": "", "behind": 0,
              "commits": [], "canUpdate": False, "error": ""}
    try:
        subprocess.run(["git", "--version"], capture_output=True, check=True)
    except (OSError, subprocess.CalledProcessError):
        return dict(result, state="no-git")
    if not is_own_checkout(directory):
        return dict(result, state="not-git")
    try:
        result["current"] = git(directory, "describe", "--tags", "--always")
        git(directory, "fetch", "--quiet", "--tags", "origin", timeout=FETCH_TIMEOUT)
    except GitError as e:
        return dict(result, ok=False, state="offline", error=str(e))
    try:
        label, commit = resolve_target(directory, channel)
        if commit is None:
            return dict(result, state="no-target")
        branch = git(directory, "branch", "--show-current")
        dirty = git(directory, "status", "--porcelain", "--untracked-files=no") != ""
        behind = int(git(directory, "rev-list", "--count", "HEAD.." + commit))
        ahead = int(git(directory, "rev-list", "--count", commit + "..HEAD"))
        commits = git(directory, "log", "--format=%s", "-n", str(MAX_COMMITS), "HEAD.." + commit) if behind else ""
    except GitError as e:
        return dict(result, ok=False, state="failed", error=str(e))
    state, can_update = decide(branch, dirty, behind, ahead)
    return dict(result, state=state, target=label, commit=commit, behind=behind,
                commits=commits.splitlines(), canUpdate=can_update)


def update(directory, channel):
    """Checks again, then fast-forwards main to the target when that is possible."""
    result = check(directory, channel)
    if not result["canUpdate"]:
        return result
    previous = result["current"]
    try:
        git(directory, "merge", "--ff-only", "--quiet", result["commit"], timeout=FETCH_TIMEOUT)
        current = git(directory, "describe", "--tags", "--always")
    except GitError as e:
        return dict(result, ok=False, state="failed", canUpdate=False, error=str(e))
    return dict(result, state="updated", canUpdate=False, previous=previous, current=current)


def main(argv=None):
    parser = argparse.ArgumentParser(description="Check for updates to the shell, and apply one.")
    parser.add_argument("action", choices=("check", "update"))
    parser.add_argument("--channel", choices=CHANNELS, default="stable")
    parser.add_argument("--dir", default=SHELL_DIR, help="the checkout to work on (default: this shell)")
    args = parser.parse_args(argv)
    run = check if args.action == "check" else update
    result = run(os.path.abspath(args.dir), args.channel)
    print(json.dumps(result))
    return 0 if result["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
