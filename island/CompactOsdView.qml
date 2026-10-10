import ".."
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    implicitHeight: Theme.compactHeight
    implicitWidth: Theme.px(230)

    // Virtual desktop switch: a row of dots with the current one stretched, and the desktop's name
    RowLayout {
        id: desktopRow
        anchors.fill: parent
        anchors.leftMargin: Theme.px(16)
        anchors.rightMargin: Theme.px(16)
        spacing: Theme.px(12)
        visible: OsdService.kind === "desktop"

        Item {
            id: dotTrack
            readonly property real dotSize: Theme.px(7)
            readonly property real dotStep: dotSize + Theme.px(6)
            // Edges of the highlight. The edge that leads the move is faster than the
            // one that follows, so the highlight stretches toward the new desktop and
            // then settles on it.
            readonly property real targetLeft: Math.max(0, WindowService.currentDesktopIndex) * dotStep
            readonly property real targetRight: targetLeft + dotSize
            property real leftEdge: targetLeft
            property real rightEdge: targetRight
            readonly property bool movingRight: targetLeft >= leftEdge

            Layout.preferredWidth: Math.max(1, WindowService.desktopCount) * dotStep - Theme.px(6)
            Layout.preferredHeight: dotSize

            Behavior on leftEdge {
                NumberAnimation { duration: dotTrack.movingRight ? 220 : 120; easing.type: Easing.OutCubic }
            }
            Behavior on rightEdge {
                NumberAnimation { duration: dotTrack.movingRight ? 120 : 220; easing.type: Easing.OutCubic }
            }

            Repeater {
                model: WindowService.desktopCount

                Rectangle {
                    x: index * dotTrack.dotStep
                    width: dotTrack.dotSize
                    height: dotTrack.dotSize
                    radius: height / 2
                    color: Theme.overlay(0.28)
                }
            }

            Rectangle {
                x: dotTrack.leftEdge
                width: dotTrack.rightEdge - dotTrack.leftEdge
                height: dotTrack.dotSize
                radius: height / 2
                color: Theme.accent
            }
        }

        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignRight
            text: WindowService.currentDesktopName
            font.family: Theme.fontDisplay
            font.pixelSize: Theme.fontPx(11)
            font.weight: Font.Bold
            color: Theme.textPrimary
            elide: Text.ElideRight
        }
    }

    RowLayout {
        anchors.fill: parent
        visible: OsdService.kind !== "desktop"
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
