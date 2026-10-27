import QtQuick
import QtTest
import "../services/settingsSearch.js" as SettingsSearchCore

TestCase {
    name: "SettingsSearch"

    function test_emptyQueryMatches() {
        verify(SettingsSearchCore.matches("", "anything"));
        verify(SettingsSearchCore.matches("   ", "anything"));
    }

    function test_caseInsensitive() {
        verify(SettingsSearchCore.matches("CLOCK", "24-Hour clock"));
    }

    function test_wordsInAnyOrder() {
        verify(SettingsSearchCore.matches("bar hide", "Auto-Hide the top bar"));
        verify(!SettingsSearchCore.matches("bar dock", "Auto-Hide the top bar"));
    }

    function test_ignoresHyphens() {
        verify(SettingsSearchCore.matches("autohide", "Auto-Hide"));
        verify(SettingsSearchCore.matches("auto-hide", "autohide pills"));
        verify(SettingsSearchCore.matches("wifi", "Wi-Fi & Network"));
    }

    function test_missingText() {
        verify(!SettingsSearchCore.matches("clock", undefined));
    }
}
