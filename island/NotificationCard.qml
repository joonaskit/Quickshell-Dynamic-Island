import ".."
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: notifCard

    property var notif: null
    property bool showApp: true

    // Native notification object (stays valid while tracked)
    readonly property var raw: notif ? notif._raw : null
    // "default" is the click action; the rest become buttons
    readonly property var actions: {
        let a = raw ? (raw.actions || []) : [];
        return a.filter(x => x.identifier !== "default");
    }
    readonly property bool hasReply: raw ? !!raw.hasInlineReply : false

    signal dismissed()

    Layout.fillWidth: true
    Layout.preferredHeight: cardLayout.implicitHeight + Theme.px(14)
    radius: Theme.px(10)
    color: cardMouse.containsMouse ? Theme.cardBackgroundHover : Theme.overlay(0.04)
    border.width: 1
    border.color: Theme.overlay(0.06)

    // Spring-in on creation
    scale: 1.0
    opacity: 1.0
    Component.onCompleted: {
        scale = 0.92;
        opacity = 0.0;
        scaleAnim.start();
        opacityAnim.start();
    }
    NumberAnimation { id: scaleAnim; target: notifCard; property: "scale"; to: 1.0; duration: Theme.animDuration; easing.type: Theme.animEasing; easing.overshoot: Theme.animEntranceOvershoot }
    NumberAnimation { id: opacityAnim; target: notifCard; property: "opacity"; to: 1.0; duration: Theme.animDurationFast }

    Behavior on color {
        ColorAnimation { duration: 120 }
    }

    MouseArea {
        id: cardMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.ArrowCursor
    }

    ColumnLayout {
        id: cardLayout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.px(7)
        spacing: Theme.px(2)

        // Top line: App Name Badge, Time & Dismiss '✕' button
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.px(6)

            // App Name
            Rectangle {
                visible: notifCard.showApp
                Layout.preferredHeight: Theme.px(16)
                Layout.preferredWidth: appText.implicitWidth + Theme.px(8)
                radius: Theme.px(4)
                color: Theme.accentTint(0.15)

                Text {
                    id: appText
                    anchors.centerIn: parent
                    text: notifCard.notif ? (notifCard.notif.appName || "System") : ""
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontPx(9)
                    font.weight: Font.DemiBold
                    color: Theme.accent
                }
            }

            Text {
                text: notifCard.notif ? (notifCard.notif.time || "") : ""
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontPx(10)
                color: Theme.textTertiary
            }

            Item { Layout.fillWidth: true }

            // Dismiss button
            Rectangle {
                Layout.preferredWidth: Theme.px(18)
                Layout.preferredHeight: Theme.px(18)
                radius: Theme.px(9)
                color: dismissMouse.containsMouse ? Qt.rgba(255/255, 69/255, 58/255, 0.25) : "transparent"
                scale: dismissMouse.pressed ? 0.88 : (dismissMouse.containsMouse ? 1.22 : 1.0)

                Behavior on color {
                    ColorAnimation { duration: 120 }
                }

                Behavior on scale {
                    NumberAnimation { duration: 150; easing.type: Easing.OutBack; easing.overshoot: 1.4 }
                }

                SvgIcon {
                    anchors.centerIn: parent
                    name: "close"
                    size: Theme.px(9)
                    color: dismissMouse.containsMouse ? Theme.accentRed : Theme.overlay(0.25)
                }

                MouseArea {
                    id: dismissMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        NotificationService.dismissNotification(notifCard.notif.id);
                    }
                }
            }
        }

        // Summary
        Text {
            visible: notifCard.notif && notifCard.notif.summary && notifCard.notif.summary.length > 0
            Layout.fillWidth: true
            text: notifCard.notif ? (notifCard.notif.summary || "") : ""
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontPx(11)
            font.weight: Font.DemiBold
            color: Theme.textPrimary
            elide: Text.ElideRight
        }

        // Body
        Text {
            visible: notifCard.notif && notifCard.notif.body && notifCard.notif.body.length > 0
            Layout.fillWidth: true
            text: notifCard.notif ? (notifCard.notif.body || "") : ""
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontPx(10)
            color: Theme.textSecondary
            wrapMode: Text.WrapAnywhere
            maximumLineCount: 2
            elide: Text.ElideRight
        }

        // Action buttons
        Flow {
            visible: notifCard.actions.length > 0
            Layout.fillWidth: true
            Layout.topMargin: Theme.px(4)
            spacing: Theme.px(6)

            Repeater {
                model: notifCard.actions

                delegate: Rectangle {
                    required property var modelData

                    width: actionLabel.implicitWidth + Theme.px(18)
                    height: Theme.px(22)
                    radius: height / 2
                    color: actionMouse.containsMouse ? Theme.accentTint(0.32) : Theme.accentTint(0.18)
                    scale: actionMouse.pressed ? 0.94 : 1.0

                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                    Text {
                        id: actionLabel
                        anchors.centerIn: parent
                        text: modelData.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontPx(10)
                        font.weight: Font.DemiBold
                        color: Theme.accent
                    }

                    MouseArea {
                        id: actionMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            let id = notifCard.notif.id;
                            modelData.invoke();
                            NotificationService.dismissNotification(id, false);
                        }
                    }
                }
            }
        }

        // Inline reply
        Rectangle {
            visible: notifCard.hasReply
            Layout.fillWidth: true
            Layout.topMargin: Theme.px(4)
            Layout.preferredHeight: Theme.px(26)
            radius: Theme.px(8)
            color: Theme.overlay(0.06)
            border.width: 1
            border.color: replyInput.activeFocus ? Theme.accentTint(0.5) : Theme.overlay(0.08)

            TextInput {
                id: replyInput
                anchors.fill: parent
                anchors.leftMargin: Theme.px(8)
                anchors.rightMargin: Theme.px(30)
                verticalAlignment: TextInput.AlignVCenter
                clip: true
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontPx(11)
                color: Theme.textPrimary
                selectionColor: Theme.accent

                onAccepted: notifCard.sendReply()

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    visible: replyInput.text.length === 0
                    text: (notifCard.raw && notifCard.raw.inlineReplyPlaceholder) ? notifCard.raw.inlineReplyPlaceholder : "Reply…"
                    font: replyInput.font
                    color: Theme.textTertiary
                    elide: Text.ElideRight
                }
            }

            // Send button
            Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: Theme.px(3)
                width: Theme.px(22)
                height: Theme.px(20)
                radius: Theme.px(7)
                color: replyInput.text.length > 0 ? Theme.accentTint(sendMouse.containsMouse ? 0.4 : 0.28) : "transparent"

                SvgIcon {
                    anchors.centerIn: parent
                    name: "chevron-right"
                    size: Theme.px(12)
                    color: replyInput.text.length > 0 ? Theme.accent : Theme.textTertiary
                }

                MouseArea {
                    id: sendMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: notifCard.sendReply()
                }
            }
        }
    }

    function sendReply() {
        let text = replyInput.text.trim();
        if (text.length === 0 || !raw) return;
        let id = notif.id;
        raw.sendInlineReply(text);
        replyInput.text = "";
        NotificationService.dismissNotification(id, false);
    }
}
