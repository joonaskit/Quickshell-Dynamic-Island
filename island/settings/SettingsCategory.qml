import "../.."
import QtQuick
import QtQuick.Layouts

// One settings tab: a column of sections
ColumnLayout {
    id: category

    // True when any section has a row matching the search query
    readonly property bool hasMatches: {
        for (let i = 0; i < children.length; i++) {
            if (children[i].hasMatches === true) return true;
        }
        return false;
    }

    Layout.fillWidth: true
    spacing: 14
}
