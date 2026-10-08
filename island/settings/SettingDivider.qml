import "../.."
import QtQuick
import QtQuick.Layouts

// Reusable Hairline Divider between settings items
Rectangle {
    Layout.fillWidth: true
    visible: !SettingsSearch.active
    Layout.preferredHeight: 1
    Layout.leftMargin: 12
    Layout.rightMargin: 12
    color: Theme.overlay(0.06)
}
