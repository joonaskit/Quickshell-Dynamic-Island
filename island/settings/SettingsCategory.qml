import "../.."
import QtQuick
import QtQuick.Layouts

// One settings tab: a column of sections
ColumnLayout {
    id: category

    // Tab name, shown above the page's matches while searching
    property string title: ""

    // True when any section has a row matching the search query
    readonly property bool hasMatches: {
        for (let i = 0; i < children.length; i++) {
            if (children[i].hasMatches === true) return true;
        }
        return false;
    }

    Layout.fillWidth: true
    spacing: 14

    Text {
        Layout.leftMargin: 4
        visible: SettingsSearch.active && category.title !== ""
        text: category.title
        font.family: Theme.fontDisplay
        font.pixelSize: Theme.fontPx(14)
        font.weight: Font.Bold
        color: Theme.textPrimary
    }
}
