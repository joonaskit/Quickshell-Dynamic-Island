"""The pure part of scripts/update_check.py: the order of release tags, and what
the state of a checkout means for an update. No git is run here, so
tests/test_update_core.py can test it directly.

Two channels:
  stable  the newest release tag (v1.2.3, v1.2.3-beta.1)
  beta    the newest commit on main
Either one only fast-forwards the main branch, so it never rewrites anything.
"""
import re

CHANNELS = ("stable", "beta")
BRANCH = "main"

TAG_RE = re.compile(r"^v(\d+)\.(\d+)\.(\d+)(?:-(alpha|beta|rc)\.(\d+))?$")
# A plain release sorts after its pre-releases
STAGES = {"alpha": 0, "beta": 1, "rc": 2, None: 3}


def version_key(tag):
    """A sortable key for a release tag, or None when the tag is not a release."""
    m = TAG_RE.match(tag)
    if not m:
        return None
    major, minor, patch, stage, number = m.groups()
    return (int(major), int(minor), int(patch), STAGES[stage], int(number or 0))


def latest_release(tags):
    """The newest release tag in `tags`, or None when there is none."""
    releases = [t for t in tags if version_key(t) is not None]
    return max(releases, key=version_key) if releases else None


def decide(branch, dirty, behind, ahead):
    """What a check found, as (state, can_update).

    `behind` is the number of commits in the target that HEAD lacks, and `ahead`
    the number in HEAD that the target lacks.

    States:
      other-branch   not on main, so updates are left to the user (a developer checkout)
      up-to-date     HEAD already holds the target (possibly with newer commits)
      diverged       both sides have commits, so a fast-forward is not possible
      local-changes  an update exists, but edited files are in the way
      available      an update exists and can be applied
    """
    if branch != BRANCH:
        return "other-branch", False
    if behind == 0:
        return "up-to-date", False
    if ahead > 0:
        return "diverged", False
    if dirty:
        return "local-changes", False
    return "available", True
