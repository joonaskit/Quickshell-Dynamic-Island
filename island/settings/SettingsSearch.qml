pragma Singleton
import QtQuick
import Quickshell
import "../../services/settingsSearch.js" as SettingsSearchCore

// Query typed into the settings search box; rows and sections filter on it
Singleton {
    property string query: ""
    readonly property string needle: query.trim().toLowerCase()
    readonly property bool active: needle !== ""

    // Every word of the query must appear in the title, the description or the
    // keywords (other words people may search with, not shown)
    function matches(title, description, keywords) {
        if (!active) return true;
        return SettingsSearchCore.matches(needle, title + " " + description + " " + (keywords || ""));
    }
}
