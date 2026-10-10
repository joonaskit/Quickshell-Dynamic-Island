import "../.."
import QtQuick
import QtQuick.Layouts

// A font family row: shows the current choice and opens a searchable list of the
// installed families. An empty value means "use the default".
Rectangle {
    id: pickerRow
    property string title: ""
    property string description: ""
    property string iconName: ""
    property color iconColor: Theme.accentBlue
    property color iconBadgeColor: Qt.rgba(iconColor.r, iconColor.g, iconColor.b, 0.18)
    // Family name, empty for the default
    property string currentValue: ""
    // Label of the empty choice, e.g. "Default" or "Same as interface font"
    property string defaultLabel: "Default"
    property bool expanded: false
    signal selected(string val)

    readonly property bool matchesSearch: SettingsSearch.matches(title, description)
    readonly property var families: {
        let needle = filterInput.text.trim().toLowerCase();
        let list = Theme.installedFonts.filter(f => needle === "" || f.toLowerCase().indexOf(needle) >= 0);
        return [""].concat(list);
    }

    Layout.fillWidth: true
    visible: matchesSearch
    implicitHeight: pickerCol.implicitHeight + 20
    color: "transparent"

    ColumnLayout {
        id: pickerCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        anchors.topMargin: 10
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Rectangle {
                visible: pickerRow.iconName !== ""
                Layout.preferredWidth: 26
                Layout.preferredHeight: 26
                radius: Theme.corner(7)
                color: pickerRow.iconBadgeColor

                SvgIcon {
                    anchors.centerIn: parent
                    name: pickerRow.iconName
                    size: 14
                    color: pickerRow.iconColor
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: pickerRow.title
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    color: Theme.textPrimary
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Text {
                    text: pickerRow.description
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    color: Theme.textSecondary
                    visible: text !== ""
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }
        }

        // Current choice; opens the list
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            radius: Theme.corner(8)
            color: currentMouse.containsMouse ? Theme.overlay(0.12) : Theme.overlay(0.08)
            Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }

            Text {
                anchors.left: parent.left
                anchors.right: chevron.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 10
                anchors.rightMargin: 6
                text: pickerRow.currentValue !== "" ? pickerRow.currentValue : pickerRow.defaultLabel
                font.family: pickerRow.currentValue !== "" ? pickerRow.currentValue : Theme.fontFamily
                font.pixelSize: 12
                color: Theme.textPrimary
                elide: Text.ElideRight
            }

            SvgIcon {
                id: chevron
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                name: pickerRow.expanded ? "chevron-up" : "chevron-down"
                size: 12
                color: Theme.textSecondary
            }

            MouseArea {
                id: currentMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    pickerRow.expanded = !pickerRow.expanded;
                    if (pickerRow.expanded) filterInput.forceActiveFocus();
                }
            }
        }

        // Search field and the list of installed families
        ColumnLayout {
            Layout.fillWidth: true
            visible: pickerRow.expanded
            spacing: 6

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                radius: Theme.corner(8)
                color: Theme.overlay(0.05)
                border.width: 1
                border.color: filterInput.activeFocus ? Theme.accentTint(0.6) : Theme.overlay(0.08)

                TextInput {
                    id: filterInput
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    color: Theme.textPrimary
                    selectionColor: Theme.accentTint(0.4)
                    selectedTextColor: Theme.textPrimary
                    clip: true
                    selectByMouse: true
                    Keys.onEscapePressed: function(event) {
                        pickerRow.expanded = false;
                        event.accepted = true;
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: filterInput.text === ""
                        text: "Search fonts"
                        font: filterInput.font
                        color: Theme.textTertiary
                    }
                }
            }

            ListView {
                id: familyList
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(contentHeight, 180)
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: pickerRow.families
                reuseItems: true

                delegate: Rectangle {
                    required property string modelData
                    width: familyList.width
                    height: 28
                    radius: Theme.corner(6)
                    readonly property bool isSelected: modelData === pickerRow.currentValue
                    color: isSelected ? Theme.accentTint(0.22) : (itemMouse.containsMouse ? Theme.overlay(0.08) : "transparent")

                    Text {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        verticalAlignment: Text.AlignVCenter
                        text: modelData !== "" ? modelData : pickerRow.defaultLabel
                        font.family: modelData !== "" ? modelData : Theme.fontFamily
                        font.pixelSize: 12
                        color: Theme.textPrimary
                        elide: Text.ElideRight
                    }

                    MouseArea {
                        id: itemMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            pickerRow.selected(modelData);
                            pickerRow.expanded = false;
                            filterInput.text = "";
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: pickerRow.families.length <= 1 && filterInput.text !== ""
                text: "No fonts match"
                font.family: Theme.fontFamily
                font.pixelSize: 11
                color: Theme.textSecondary
            }
        }
    }
}
