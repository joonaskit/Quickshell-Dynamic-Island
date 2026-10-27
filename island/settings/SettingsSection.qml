import "../.."
import QtQuick
import QtQuick.Layouts

// Titled card that groups setting rows
ColumnLayout {
    id: section
    property string title: ""
    property string subtitle: ""
    // Name for opening the window at this section, see SettingsService.requestOpenSettings
    property string key: ""
    property real titlePixelSize: 10
    default property alias rows: rowsCol.data

    // True when any row matches the search query
    readonly property bool hasMatches: {
        let items = rowsCol.children;
        for (let i = 0; i < items.length; i++) {
            if (items[i].matchesSearch === true) return true;
        }
        return false;
    }

    // Briefly outlines the section, after the window was opened at it
    function highlight() {
        highlightAnim.restart();
    }

    Layout.fillWidth: true
    visible: !SettingsSearch.active || hasMatches
    spacing: 6

    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 4
        spacing: 6

        Text {
            text: section.title
            font.family: Theme.fontFamily
            font.pixelSize: section.titlePixelSize
            font.weight: Font.DemiBold
            color: Theme.textTertiary
        }

        Text {
            visible: section.subtitle !== ""
            text: "• " + section.subtitle
            font.family: Theme.fontFamily
            font.pixelSize: section.titlePixelSize
            color: Theme.overlay(0.25)
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: rowsCol.implicitHeight
        radius: Theme.corner(14)
        color: Theme.overlay(0.04)
        border.width: 1
        border.color: Theme.overlay(0.08)

        Rectangle {
            id: highlightRing
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.width: 2
            border.color: Theme.accent
            opacity: 0
        }

        SequentialAnimation {
            id: highlightAnim
            NumberAnimation { target: highlightRing; property: "opacity"; to: 1; duration: Theme.animDurationFast }
            PauseAnimation { duration: 700 }
            NumberAnimation { target: highlightRing; property: "opacity"; to: 0; duration: Theme.animDuration }
        }

        ColumnLayout {
            id: rowsCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            spacing: 0
        }
    }
}
