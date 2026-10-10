import ".."
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    signal requestClose()

    property bool embedded: false

    implicitWidth: embedded ? (parent ? parent.width : 340) : 320
    implicitHeight: mainCard.height

    // Soft Drop Shadow
    Rectangle {
        id: cardShadow
        anchors.centerIn: mainCard
        width: mainCard.width + 16
        height: mainCard.height + 12
        radius: mainCard.radius + 4
        color: Theme.islandShadow
        opacity: 0.7
        visible: !root.embedded
    }

    // Main Control Center Card
    Rectangle {
        id: mainCard
        width: root.embedded ? (root.parent ? root.parent.width : root.width) : root.implicitWidth
        height: contentColumn.implicitHeight + (root.embedded ? 14 : 28)
        radius: root.embedded ? 0 : 18
        color: root.embedded ? "transparent" : Theme.cardBackground
        border.width: root.embedded ? 0 : 1
        border.color: Theme.overlay(0.12)
        clip: true

        ColumnLayout {
            id: contentColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: root.embedded ? 10 : 14
            spacing: 12

            // Top Header: Badge, Title & Empty Button
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                // Circular Clipboard Badge
                Rectangle {
                    Layout.preferredWidth: 38
                    Layout.preferredHeight: 38
                    radius: 19
                    color: Theme.accentTint(0.2)

                    SvgIcon {
                        anchors.centerIn: parent
                        name: "clipboard"
                        size: 20
                        color: Theme.accent
                    }
                }

                // Title & Subtitle Readout
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: "Clipboard"
                        font.family: Theme.fontDisplay
                        font.pixelSize: 15
                        font.weight: Font.Bold
                        color: Theme.textPrimary
                    }

                    Text {
                        text: {
                            if (ClipboardService.currentFiles.length > 0)
                                return ClipboardService.currentFiles.length === 1 ? "File on clipboard" : ClipboardService.currentFiles.length + " files on clipboard";
                            if (ClipboardService.currentBinaryType !== "")
                                return ClipboardService.currentBinaryType.startsWith("image/") ? "Image on clipboard" : "Non-text content on clipboard";
                            if (ClipboardService.currentText !== "") {
                                let len = ClipboardService.history.length;
                                return len > 1 ? (len + " items saved") : "1 item active";
                            }
                            return "Clipboard is empty";
                        }
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: Theme.textSecondary
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                // Empty / Clear Button
                Rectangle {
                    id: emptyBtn
                    Layout.preferredHeight: 28
                    Layout.preferredWidth: emptyRow.implicitWidth + 18
                    radius: 14
                    enabled: ClipboardService.currentText !== "" || ClipboardService.currentBinaryType !== "" || ClipboardService.currentFiles.length > 0 || ClipboardService.history.length > 0
                    opacity: enabled ? 1.0 : 0.35
                    scale: emptyMouse.pressed ? 0.92 : (emptyMouse.containsMouse && enabled ? 1.05 : 1.0)
                    color: emptyMouse.containsMouse ? Qt.rgba(255/255, 69/255, 58/255, 0.24) : Qt.rgba(255/255, 69/255, 58/255, 0.12)

                    Behavior on color {
                        ColorAnimation { duration: Theme.animDurationFast }
                    }
                    Behavior on opacity {
                        NumberAnimation { duration: Theme.animDurationFast }
                    }
                    Behavior on scale {
                        NumberAnimation { duration: Theme.animDurationTooltip; easing.type: Easing.OutCubic }
                    }

                    RowLayout {
                        id: emptyRow
                        anchors.centerIn: parent
                        spacing: 5

                        SvgIcon {
                            name: "trash"
                            size: 13
                            color: Theme.accentRed
                        }

                        Text {
                            text: "Empty"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            color: Theme.accentRed
                        }
                    }

                    MouseArea {
                        id: emptyMouse
                        anchors.fill: parent
                        hoverEnabled: parent.enabled
                        cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            ClipboardService.clearClipboard();
                        }
                    }
                }
            }

            // Divider
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.overlay(0.08)
            }

            // Section 1: Active Clipboard Preview
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "CURRENT CONTENT"
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        color: Theme.textTertiary
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        visible: ClipboardService.currentText !== "" || ClipboardService.currentBinaryType !== "" || ClipboardService.currentFiles.length > 0
                        text: ClipboardService.currentFiles.length > 0 ? "files"
                            : (ClipboardService.currentBinaryType !== "" ? ClipboardService.currentBinaryType : ClipboardService.currentText.length + " chars")
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        color: Theme.textSecondary
                    }
                }

                // Active Card Container
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: activeCardContent.implicitHeight + 16
                    radius: Theme.corner(12)
                    color: Theme.overlay(0.05)
                    border.width: 1
                    border.color: Theme.overlay(0.08)

                    ColumnLayout {
                        id: activeCardContent
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 10
                        spacing: 6

                        // When Clipboard has content
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: previewText.implicitHeight
                            visible: ClipboardService.currentText !== ""

                            Text {
                                id: previewText
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                text: ClipboardService.currentText
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                color: Theme.textPrimary
                                wrapMode: Text.WrapAnywhere
                                maximumLineCount: 4
                                elide: Text.ElideRight
                                lineHeight: 1.2
                            }
                        }

                        // When Clipboard holds an image
                        Image {
                            id: clipImage
                            Layout.fillWidth: true
                            Layout.preferredHeight: status === Image.Ready ? Math.min(160, width * implicitHeight / Math.max(1, implicitWidth)) : 0
                            visible: ClipboardService.imageSource !== "" && status === Image.Ready
                            source: ClipboardService.imageSource
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            cache: false
                            sourceSize.width: 600
                        }

                        // File names, when files are copied
                        Text {
                            Layout.fillWidth: true
                            visible: ClipboardService.currentFiles.length > 0
                            text: ClipboardService.currentFiles.map(f => f.split("/").pop()).join("\n")
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            color: Theme.textPrimary
                            elide: Text.ElideMiddle
                            maximumLineCount: 4
                        }

                        // When Clipboard is empty
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 28
                            visible: ClipboardService.currentText === "" && ClipboardService.currentFiles.length === 0 && !(ClipboardService.imageSource !== "" && clipImage.status === Image.Ready)
                            spacing: 8

                            SvgIcon {
                                name: "clipboard"
                                size: 14
                                color: Theme.overlay(0.25)
                            }

                            Text {
                                text: ClipboardService.currentBinaryType !== "" ? (ClipboardService.currentBinaryType.startsWith("image/") ? "Image (" : "Non-text content (") + ClipboardService.currentBinaryType + ")" : "Nothing copied yet"
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                color: Theme.textSecondary
                            }
                        }
                    }
                }
            }

            // Section 2: Recent History List (if more than 1 item exists)
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6
                opacity: ClipboardService.history.length > 1 ? 1.0 : 0.0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: Theme.animDurationFast } }

                // Divider
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Theme.overlay(0.08)
                    Layout.bottomMargin: 2
                }

                Text {
                    text: "RECENT COPIES"
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    color: Theme.textTertiary
                }

                Repeater {
                    model: {
                        let h = ClipboardService.history || [];
                        // Skip the first item since it is already shown in current content
                        return h.slice(1, Math.min(h.length, 6));
                    }

                    Rectangle {
                        id: historyItemRow
                        Layout.fillWidth: true
                        Layout.preferredHeight: 32
                        radius: Theme.corner(8)
                        color: histMouse.containsMouse ? Theme.overlay(0.08) : Theme.overlay(0.03)

                        Behavior on color {
                            ColorAnimation { duration: Theme.animDurationTooltip }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 8

                            SvgIcon {
                                name: "copy"
                                size: 12
                                color: histMouse.containsMouse ? Theme.accent : Theme.overlay(0.3)
                            }

                            Text {
                                Layout.fillWidth: true
                                text: modelData.replace(/[\r\n\t]+/g, " ").trim()
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                color: Theme.textPrimary
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }

                            // Remove item button
                            Rectangle {
                                Layout.preferredWidth: 20
                                Layout.preferredHeight: 20
                                radius: 10
                                color: delMouse.containsMouse ? Qt.rgba(255/255, 69/255, 58/255, 0.25) : "transparent"
                                scale: delMouse.pressed ? 0.88 : (delMouse.containsMouse ? 1.15 : 1.0)

                                Behavior on color {
                                    ColorAnimation { duration: Theme.animDurationTooltip }
                                }
                                Behavior on scale {
                                    NumberAnimation { duration: Theme.animDurationTooltip; easing.type: Easing.OutCubic }
                                }

                                SvgIcon {
                                    anchors.centerIn: parent
                                    name: "close"
                                    size: 10
                                    color: delMouse.containsMouse ? Theme.accentRed : Theme.overlay(0.25)
                                }

                                MouseArea {
                                    id: delMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        // model index corresponds to actual index + 1 in history
                                        ClipboardService.removeItem(index + 1);
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: histMouse
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.right: parent.right
                            anchors.rightMargin: 24
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                ClipboardService.copyText(modelData);
                            }
                        }
                    }
                }
            }
        }
    }
}
