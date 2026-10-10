import ".."
import QtQuick
import QtQuick.Layouts

// The activity the island favours, shown in the compact pill. A failed one
// carries a dismiss button and stays until the user removes it.
Item {
    id: root

    readonly property var activity: ActivityService.current
    readonly property bool failed: ActivityService.hasFailed
    readonly property string activityState: activity ? activity.state : "running"
    readonly property real progress: (activity && activity.progress !== null) ? activity.progress : -2
    readonly property color accent: ActivityService.accentFor(root.activityState)
    // Finished ones say so; a running one says what it is doing
    readonly property string detail: {
        if (!activity) return "";
        if (root.activityState !== "running") return ActivityService.stateLabel(activity);
        return activity.text;
    }

    implicitHeight: Theme.compactHeight
    implicitWidth: Theme.px(260)

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.px(12)
        anchors.rightMargin: Theme.px(12)
        spacing: Theme.px(9)

        // Icon with a progress ring around it
        Item {
            Layout.preferredWidth: Theme.px(24)
            Layout.preferredHeight: Theme.px(24)

            Canvas {
                id: ring
                anchors.fill: parent
                // -2: the activity gave no progress, so there is no ring to draw
                visible: root.progress > -2 && root.activityState === "running"
                property real value: root.progress
                property real spin: 0
                property color ringColor: root.accent
                onValueChanged: requestPaint()
                onSpinChanged: requestPaint()
                onRingColorChanged: requestPaint()
                onPaint: {
                    let ctx = getContext("2d");
                    ctx.reset();
                    let c = width / 2;
                    let r = c - 1.5;
                    ctx.lineWidth = 2;
                    ctx.lineCap = "round";
                    ctx.strokeStyle = Theme.overlay(0.16);
                    ctx.beginPath();
                    ctx.arc(c, c, r, 0, Math.PI * 2);
                    ctx.stroke();
                    ctx.strokeStyle = ringColor;
                    ctx.beginPath();
                    if (value < 0) {
                        let a = spin * Math.PI * 2;
                        ctx.arc(c, c, r, a, a + Math.PI * 0.6);
                    } else {
                        ctx.arc(c, c, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * Math.max(0.001, Math.min(1, value)));
                    }
                    ctx.stroke();
                }

                NumberAnimation on spin {
                    running: ring.visible && root.progress < 0 && root.visible
                    from: 0
                    to: 1
                    duration: 1100
                    loops: Animation.Infinite
                }
            }

            ActivityIcon {
                anchors.centerIn: parent
                icon: root.failed ? "" : (root.activity ? root.activity.icon : "")
                fallback: root.failed ? "alert" : (root.activityState === "done" ? "check" : "download")
                size: Theme.px(14)
                color: root.accent
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
                Layout.fillWidth: true
                text: root.activity ? root.activity.title : ""
                elide: Text.ElideRight
                font.family: Theme.fontDisplay
                font.pixelSize: Theme.fontPx(root.detail !== "" ? 11 : 13)
                font.weight: Font.DemiBold
                color: Theme.textPrimary
            }

            Text {
                Layout.fillWidth: true
                visible: root.detail !== ""
                text: root.detail
                elide: Text.ElideRight
                font.family: Theme.fontDisplay
                font.pixelSize: Theme.fontPx(10)
                color: root.failed ? Theme.accentRed : Theme.textSecondary
            }
        }

        // Percent for a running activity with a known total
        Text {
            visible: root.activityState === "running" && root.progress >= 0
            text: Math.round(root.progress * 100) + "%"
            font.family: Theme.fontDisplay
            font.pixelSize: Theme.fontPx(12)
            font.weight: Font.Bold
            font.features: { "tnum": 1 }
            color: Theme.textPrimary
        }

        // How many others are waiting in the expanded view
        Rectangle {
            visible: ActivityService.count > 1
            Layout.preferredWidth: Math.max(height, countLabel.implicitWidth + Theme.px(10))
            Layout.preferredHeight: Theme.px(18)
            radius: height / 2
            color: Theme.overlay(0.14)

            Text {
                id: countLabel
                anchors.centerIn: parent
                text: "+" + (ActivityService.count - 1)
                font.family: Theme.fontDisplay
                font.pixelSize: Theme.fontPx(10)
                font.weight: Font.DemiBold
                color: Theme.textSecondary
            }
        }

        // A failure stays until dismissed
        Rectangle {
            visible: root.failed
            Layout.preferredWidth: Theme.px(22)
            Layout.preferredHeight: Theme.px(22)
            radius: width / 2
            color: dismissMouse.containsMouse ? Theme.overlay(0.2) : Theme.overlay(0.1)

            SvgIcon {
                anchors.centerIn: parent
                name: "close"
                size: Theme.px(11)
                color: Theme.textPrimary
            }

            MouseArea {
                id: dismissMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: ActivityService.dismiss(root.activity.key)
            }
        }
    }
}
