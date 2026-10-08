import ".."
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    implicitHeight: Theme.compactHeight
    implicitWidth: Theme.px(230)

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.px(14)
        anchors.rightMargin: Theme.px(16)
        spacing: Theme.px(10)

        SvgIcon {
            name: OsdService.iconName
            size: Theme.px(16)
            color: OsdService.isMuted ? Theme.textTertiary : (OsdService.kind === "volume" ? Theme.accentBlue : Theme.accentOrange)
        }

        // Level bar
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.px(5)
            radius: height / 2
            color: Theme.overlay(0.14)

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, OsdService.value))
                height: parent.height
                radius: height / 2
                color: OsdService.kind === "volume" ? Theme.accentBlue : Theme.accentOrange

                Behavior on width { NumberAnimation { duration: Theme.animDurationFast; easing.type: Easing.OutCubic } }
            }
        }

        Text {
            Layout.preferredWidth: Theme.px(30)
            horizontalAlignment: Text.AlignRight
            text: Math.round(OsdService.value * 100)
            font.family: Theme.fontDisplay
            font.pixelSize: Theme.fontPx(11)
            font.weight: Font.Bold
            color: Theme.textPrimary
        }
    }
}
