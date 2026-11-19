import QtQuick
import QtTest
import "../services/desktopConflicts.js" as Conflicts

TestCase {
    name: "DesktopConflicts"

    function test_parse_self() {
        let c = Conflicts.parse("owner=self\n");
        compare(c.ownsNotifications, true);
        compare(c.notificationOwner, "");
        compare(c.waybar, false);
    }

    function test_parse_other_owner_and_waybar() {
        let c = Conflicts.parse("owner=mako\nwaybar=1\n");
        compare(c.ownsNotifications, false);
        compare(c.notificationOwner, "mako");
        compare(c.waybar, true);
    }

    function test_parse_no_owner() {
        let c = Conflicts.parse("owner=\n");
        compare(c.ownsNotifications, false);
        compare(c.notificationOwner, "");
    }

    function test_parse_garbage() {
        let c = Conflicts.parse("Failed to connect\n\n");
        compare(c.notificationOwner, "");
        compare(c.waybar, false);
        compare(Conflicts.parse(undefined).waybar, false);
    }

    function test_known_daemon_fix() {
        compare(Conflicts.notificationFix("mako").command, "systemctl --user mask --now mako.service");
        compare(Conflicts.notificationFix("dunst").command, "systemctl --user mask --now dunst.service");
    }

    function test_unknown_daemon_fix() {
        compare(Conflicts.notificationFix("xfce4-notifyd").command, "");
        verify(Conflicts.notificationFix("xfce4-notifyd").text.length > 0);
    }

    function test_waybar_fix() {
        verify(Conflicts.waybarFix(true).text.indexOf("spawn-at-startup") >= 0);
        verify(Conflicts.waybarFix(false).text.indexOf("spawn-at-startup") < 0);
    }

    function test_summary() {
        compare(Conflicts.summary({ "notificationOwner": "mako", "waybar": true }).length, 2);
        compare(Conflicts.summary({ "notificationOwner": "", "waybar": false }).length, 0);
    }
}
