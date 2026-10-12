#!/usr/bin/env python3
"""GameMode helper for GameModeService.

Talks to gamemoded over the session bus with busctl. Output is JSON.

Commands:
  status        whether gamemoded is reachable, the registered games and whether
                the shell itself is registered ("forced")
  force-on      register the shell (this script's parent) as a game
  force-off     unregister it

GameMode drops a registered process when it exits, so a forced registration
never outlives the shell.
"""
import json
import os
import re
import subprocess
import sys

SERVICE = "com.feralinteractive.GameMode"
PATH = "/com/feralinteractive/GameMode"
GAME_PATH = re.compile(r'(\d+) "/com/feralinteractive/GameMode/Games/\d+"')


class GameModeError(Exception):
    pass


def busctl(*args):
    try:
        result = subprocess.run(["busctl", "--user", *args], capture_output=True, text=True, timeout=5)
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise GameModeError(str(exc)) from exc
    if result.returncode != 0:
        raise GameModeError(result.stderr.strip() or "busctl failed")
    return result.stdout


def parse_games(output):
    """Pids from the reply to ListGames, e.g. 'a(io) 1 1234 "/com/.../Games/1234"'."""
    return [int(pid) for pid in GAME_PATH.findall(output)]


def process_name(pid):
    try:
        with open(f"/proc/{pid}/comm") as f:
            return f.read().strip()
    except OSError:
        return str(pid)


def cmd_status():
    shell_pid = os.getppid()
    try:
        pids = parse_games(busctl("call", SERVICE, PATH, SERVICE, "ListGames"))
    except GameModeError:
        print(json.dumps({"available": False, "games": [], "forced": False}))
        return
    games = [{"pid": pid, "name": process_name(pid)} for pid in pids if pid != shell_pid]
    print(json.dumps({"available": True, "games": games, "forced": shell_pid in pids}))


def set_forced(on):
    method = "RegisterGame" if on else "UnregisterGame"
    busctl("call", SERVICE, PATH, SERVICE, method, "i", str(os.getppid()))


def main(argv):
    if len(argv) != 2 or argv[1] not in ("status", "force-on", "force-off"):
        print(__doc__, file=sys.stderr)
        return 2
    try:
        if argv[1] == "status":
            cmd_status()
        else:
            set_forced(argv[1] == "force-on")
    except GameModeError as exc:
        print(json.dumps({"error": str(exc)}))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
