import "../.."
import QtQuick
import QtQuick.Layouts

// Sketch of the top edge of the screen as the settings have it: pill style, full-width
// bar, which pills show and the status icons in order. Each part opens its settings
// section. Hidden while searching
ColumnLayout {
    id: diagram

    // Shown under the sketch while the pointer is over a part
    property string hoveredLabel: ""
    readonly property bool flat: SettingsService.topBarMode === "always"
    readonly property bool notch: Theme.notchStyle && !flat
    readonly property var systemIcons: SettingsService.orderedStatusIcons.filter(i => i.group === "system" && SettingsService[i.settingKey])
    readonly property var optionalIcons: SettingsService.orderedStatusIcons.filter(i => i.group === "widgets" && SettingsService[i.settingKey])

    function pairLabel(key, subKey) {
        let v = SettingsService.pairValue(key, subKey);
        return v === "off" ? "off" : (v === "sub" ? "auto-hide" : "shown");
    }

    Layout.fillWidth: true
    visible: !SettingsSearch.active
    spacing: 6

    // One part of the bar. `shown` false draws an outline only, `faded` (auto-hide) dims it
    component Part: Rectangle {
        id: part
        property string label: ""
        property string tab: "Top bar"
        property string section: ""
        property bool shown: true
        property bool faded: false
        property bool frosted: false
        default property alias content: partRow.data

        Layout.preferredHeight: 22
        Layout.alignment: Qt.AlignTop
        Layout.topMargin: diagram.notch || diagram.flat ? 0 : 5
        implicitWidth: partRow.implicitWidth + 16
        radius: 11
        topLeftRadius: diagram.notch || diagram.flat ? 0 : radius
        topRightRadius: diagram.notch || diagram.flat ? 0 : radius
        color: !shown || diagram.flat ? "transparent" : (frosted ? Theme.pillFrosted : Theme.islandBackground)
        border.width: partMouse.containsMouse ? 1.5 : 1
        border.color: partMouse.containsMouse ? Theme.accent : (shown && !diagram.flat ? Theme.overlay(0.12) : Theme.overlay(0.18))
        opacity: faded ? 0.55 : 1.0

        Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }

        RowLayout {
            id: partRow
            anchors.centerIn: parent
            spacing: 3
            opacity: part.shown ? 1.0 : 0.35
        }

        MouseArea {
            id: partMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onContainsMouseChanged: {
                if (containsMouse) diagram.hoveredLabel = part.label;
                else if (diagram.hoveredLabel === part.label) diagram.hoveredLabel = "";
            }
            onClicked: SettingsService.requestOpenSettings(part.tab, part.section)
        }
    }

    component Dot: Rectangle {
        Layout.alignment: Qt.AlignVCenter
        implicitWidth: 5
        implicitHeight: 5
        radius: 2.5
        color: Theme.textSecondary
    }

    component Icon: SvgIcon {
        Layout.alignment: Qt.AlignVCenter
        size: 10
        color: Theme.textSecondary
    }

    // The screen's top edge
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 52
        radius: Theme.corner(14)
        color: Theme.overlay(0.04)
        border.width: 1
        border.color: Theme.overlay(0.08)
        clip: true

        // Full-width bar
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 23
            topLeftRadius: parent.radius
            topRightRadius: parent.radius
            color: Theme.islandBackground
            visible: diagram.flat
        }

        RowLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 4

            Part {
                label: "Window controls: " + diagram.pairLabel("showWindowControls", "autoHideWindowControls")
                section: "pills"
                shown: SettingsService.showWindowControls
                faded: SettingsService.autoHideWindowControls

                Icon { name: "window" }
                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 4
                    radius: 2
                    color: Theme.overlay(0.3)
                }
            }

            Part {
                label: "Virtual desktops: " + diagram.pairLabel("showVirtualDesktops", "autoHideVirtualDesktops")
                section: "pills"
                shown: SettingsService.showVirtualDesktops
                faded: SettingsService.autoHideVirtualDesktops
                frosted: true

                Dot { color: Theme.accent }
                Dot {}
                Dot {}
            }

            Item { Layout.fillWidth: true }

            Part {
                label: "Island: what it shows, cards and clock"
                tab: "Island"
                section: "compact"
                implicitWidth: 76

                Text {
                    text: Qt.formatTime(new Date(), SettingsService.use24Hour ? "HH:mm" : "h:mm")
                    font.family: Theme.fontDisplay
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    color: Theme.textPrimary
                }
            }

            Part {
                label: "Notification bubble: " + (SettingsService.showDetachedNotifBubble ? "shown" : "off")
                tab: "Island"
                section: "compact"
                shown: SettingsService.showDetachedNotifBubble
                implicitWidth: 22

                Dot { color: Theme.accentOrange }
            }

            Item { Layout.fillWidth: true }

            Part {
                label: "App tray: " + diagram.pairLabel("showAppTrayPill", "autoHideAppTrayPill")
                section: "pills"
                shown: SettingsService.showAppTrayPill
                faded: SettingsService.autoHideAppTrayPill
                frosted: true

                Dot {}
                Dot {}
            }

            Part {
                label: diagram.optionalIcons.length > 0 ? "Optional icons" : "Optional icons: none turned on"
                section: "optionalIcons"
                shown: diagram.optionalIcons.length > 0
                frosted: SettingsService.frostedStatusIcons

                Icon {
                    name: "plus"
                    visible: diagram.optionalIcons.length === 0
                }
                Repeater {
                    model: diagram.optionalIcons
                    delegate: Icon {
                        required property var modelData
                        name: modelData.icon
                    }
                }
            }

            Part {
                label: "Status icons"
                section: "statusIcons"
                shown: diagram.systemIcons.length > 0
                frosted: SettingsService.frostedStatusIcons

                Icon {
                    name: "plus"
                    visible: diagram.systemIcons.length === 0
                }
                Repeater {
                    model: diagram.systemIcons
                    delegate: Icon {
                        required property var modelData
                        name: modelData.icon
                    }
                }
            }
        }
    }

    Text {
        Layout.fillWidth: true
        Layout.leftMargin: 4
        text: diagram.hoveredLabel !== "" ? diagram.hoveredLabel : "Click a part of the bar to go to its settings"
        font.family: Theme.fontFamily
        font.pixelSize: 10
        color: diagram.hoveredLabel !== "" ? Theme.textPrimary : Theme.textTertiary
        elide: Text.ElideRight
    }
}
