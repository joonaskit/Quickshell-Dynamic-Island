import QtQuick
import QtTest
import "../services/lockCommand.js" as LockCommand

TestCase {
    name: "LockCommand"

    function test_kde_uses_logind() {
        compare(LockCommand.lockCommand("kde", "", ["swaylock"]), ["loginctl", "lock-session"]);
    }

    function test_niri_prefers_swaylock() {
        compare(LockCommand.lockCommand("niri", "", ["gtklock", "swaylock"]), ["swaylock", "-f"]);
    }

    function test_niri_other_lockers() {
        compare(LockCommand.lockCommand("niri", "", ["hyprlock"]), ["hyprlock"]);
        compare(LockCommand.lockCommand("other", "", ["gtklock"]), ["gtklock", "-d"]);
    }

    function test_no_locker_falls_back_to_logind() {
        compare(LockCommand.lockCommand("niri", "", []), ["loginctl", "lock-session"]);
        compare(LockCommand.lockCommand("niri", undefined, undefined), ["loginctl", "lock-session"]);
    }

    function test_custom_command_wins_everywhere() {
        compare(LockCommand.lockCommand("niri", "waylock -fork-on-lock", ["swaylock"]), ["sh", "-c", "waylock -fork-on-lock"]);
        compare(LockCommand.lockCommand("kde", "my-lock", []), ["sh", "-c", "my-lock"]);
        compare(LockCommand.lockCommand("niri", "   ", ["swaylock"]), ["swaylock", "-f"]);
    }

    function test_parse_found() {
        compare(LockCommand.parseFound("/usr/bin/swaylock\n/usr/bin/gtklock\n"), ["swaylock", "gtklock"]);
        compare(LockCommand.parseFound(""), []);
    }
}
