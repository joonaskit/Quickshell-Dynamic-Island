pragma Singleton
import QtQuick
import Quickshell

// Query typed into the settings search box; rows and sections filter on it
Singleton {
    property string query: ""
    readonly property string needle: query.trim().toLowerCase()
    readonly property bool active: needle !== ""

    function matches(title, description) {
        if (!active) return true;
        return (title + " " + description).toLowerCase().indexOf(needle) >= 0;
    }
}
