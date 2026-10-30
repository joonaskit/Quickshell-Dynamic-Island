import ".."
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    signal requestClose()

    property bool embedded: false

    readonly property var light: HueService.selectedLight
    readonly property bool isFavourite: light !== null && light.id === HueService.favouriteId
    readonly property var otherLights: HueService.lights.filter(l => root.light === null || l.id !== root.light.id)
    property bool othersExpanded: false

    // Back to the favourite each time the popup closes
    onVisibleChanged: {
        if (!visible) {
            HueService.viewedId = "";
            othersExpanded = false;
        }
    }
    readonly property color hueColor: Theme.accentOrangeStrong

    implicitWidth: embedded ? (parent ? parent.width : Theme.px(340)) : Theme.px(320)
    implicitHeight: mainCard.height

    Rectangle {
        id: cardShadow
        anchors.centerIn: mainCard
        width: mainCard.width + Theme.px(16)
        height: mainCard.height + Theme.px(12)
        radius: mainCard.radius + Theme.px(4)
        color: Theme.islandShadow
        opacity: 0.7
        visible: !root.embedded
    }

    // Inline components cannot see this file's ids, so they use Theme directly
    // Rounded slider shared by the brightness and color temperature rows
    component HueSlider: ColumnLayout {
        id: slider

        property string label: ""
        property string valueText: ""
        property real position: 0
        property color fillColor: Theme.accentOrange
        signal moved(real position)

        Layout.fillWidth: true
        spacing: Theme.px(6)

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: slider.label
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontPx(10)
                font.weight: Font.DemiBold
                color: Theme.textTertiary
            }

            Item { Layout.fillWidth: true }

            Text {
                text: slider.valueText
                font.family: Theme.fontDisplay
                font.pixelSize: Theme.fontPx(11)
                font.weight: Font.DemiBold
                color: slider.fillColor
            }
        }

        Rectangle {
            id: track
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.px(28)
            radius: Theme.px(14)
            color: Theme.overlay(0.08)

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: Math.max(track.height, track.width * slider.position)
                radius: Theme.corner(14)
                color: slider.fillColor
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor

                function update(mouse) {
                    slider.moved(Math.max(0.0, Math.min(1.0, mouse.x / track.width)));
                }

                onPressed: (mouse) => update(mouse)
                onPositionChanged: (mouse) => {
                    if (pressed) update(mouse);
                }
            }
        }
    }

    // Small pill button used for Find, Pair and Forget
    component HueButton: Rectangle {
        id: button

        property string text: ""
        property bool busy: false
        signal clicked()

        Layout.preferredHeight: Theme.px(28)
        Layout.preferredWidth: buttonLabel.implicitWidth + Theme.px(24)
        radius: Theme.px(14)
        color: buttonMouse.containsMouse && !busy ? Theme.accentTint(0.3) : Theme.overlay(0.1)
        opacity: busy ? 0.6 : 1.0
        Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }

        Text {
            id: buttonLabel
            anchors.centerIn: parent
            text: button.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontPx(10)
            font.weight: Font.Bold
            color: Theme.textPrimary
        }

        MouseArea {
            id: buttonMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: if (!button.busy) button.clicked()
        }
    }

    Rectangle {
        id: mainCard
        width: root.embedded ? (root.parent ? root.parent.width : root.width) : root.implicitWidth
        height: contentColumn.implicitHeight + (root.embedded ? Theme.px(14) : Theme.px(28))
        radius: root.embedded ? 0 : Theme.px(18)
        color: root.embedded ? "transparent" : Theme.cardSurface
        border.width: root.embedded ? 0 : 1
        border.color: Theme.overlay(0.12)
        clip: true

        ColumnLayout {
            id: contentColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: root.embedded ? Theme.px(10) : Theme.px(14)
            spacing: Theme.px(12)

            // Header: badge, title and power button
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.px(12)

                Rectangle {
                    Layout.preferredWidth: Theme.px(38)
                    Layout.preferredHeight: Theme.px(38)
                    radius: Theme.px(19)
                    color: HueService.anyOn ? Qt.rgba(255/255, 159/255, 10/255, 0.22) : Theme.cardSurfaceHover
                    Behavior on color { ColorAnimation { duration: 180 } }

                    SvgIcon {
                        anchors.centerIn: parent
                        name: "bulb"
                        size: Theme.px(20)
                        color: HueService.anyOn ? root.hueColor : Theme.textTertiary
                        Behavior on color { ColorAnimation { duration: 180 } }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Theme.px(2)

                    Text {
                        text: "Philips Hue"
                        font.family: Theme.fontDisplay
                        font.pixelSize: Theme.fontPx(13)
                        font.weight: Font.DemiBold
                        color: Theme.textPrimary
                    }

                    Text {
                        text: {
                            if (HueService.error !== "") return HueService.error;
                            if (!HueService.paired) return "Not connected to a bridge";
                            if (!HueService.connected) return "Connecting...";
                            if (root.light) return root.light.name;
                            return "No lights found";
                        }
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontPx(11)
                        color: HueService.error !== "" ? Theme.accentRed : Theme.textSecondary
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                Rectangle {
                    visible: root.light !== null
                    Layout.preferredWidth: Theme.px(28)
                    Layout.preferredHeight: Theme.px(28)
                    radius: Theme.px(14)
                    color: root.isFavourite ? Qt.rgba(255/255, 159/255, 10/255, 0.25) : (pinMouse.containsMouse ? Theme.overlay(0.1) : "transparent")
                    Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }

                    SvgIcon {
                        anchors.centerIn: parent
                        name: "pin"
                        size: Theme.px(13)
                        color: root.isFavourite ? root.hueColor : Theme.textSecondary
                    }

                    MouseArea {
                        id: pinMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: HueService.toggleFavourite(root.light.id)
                    }
                }

                Rectangle {
                    visible: root.light !== null
                    Layout.preferredWidth: Theme.px(64)
                    Layout.preferredHeight: Theme.px(28)
                    radius: Theme.px(14)
                    color: root.light && root.light.on ? Qt.rgba(255/255, 159/255, 10/255, 0.25) : Theme.overlay(0.1)
                    scale: powerMouse.pressed ? 0.92 : (powerMouse.containsMouse ? 1.05 : 1.0)
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

                    Text {
                        anchors.centerIn: parent
                        text: root.light && root.light.on ? "ON" : "OFF"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontPx(10)
                        font.weight: Font.Bold
                        color: root.light && root.light.on ? root.hueColor : Theme.textSecondary
                    }

                    MouseArea {
                        id: powerMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: HueService.toggle(root.light.id)
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.overlay(0.08)
            }

            // Setup: bridge address and pairing
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.px(8)
                visible: !HueService.paired

                Text {
                    text: HueService.pairState === "waiting"
                        ? "Press the round link button on the bridge, then pair again."
                        : "Enter the bridge address, then press its link button and pair."
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontPx(11)
                    color: HueService.pairState === "waiting" ? Theme.accentOrangeStrong : Theme.textSecondary
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.px(8)

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Theme.px(30)
                        radius: Theme.corner(8)
                        color: Theme.overlay(0.05)
                        border.width: 1
                        border.color: bridgeInput.activeFocus ? Theme.accentTint(0.6) : Theme.overlay(0.08)

                        TextInput {
                            id: bridgeInput
                            anchors.fill: parent
                            anchors.leftMargin: Theme.px(10)
                            anchors.rightMargin: Theme.px(10)
                            verticalAlignment: TextInput.AlignVCenter
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontPx(12)
                            color: Theme.textPrimary
                            selectionColor: Theme.accentTint(0.4)
                            selectedTextColor: Theme.textPrimary
                            clip: true
                            selectByMouse: true
                            inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhUrlCharactersOnly
                            text: SettingsService.hueBridgeIp
                            onEditingFinished: HueService.setBridge(text)
                            onAccepted: HueService.pair()

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: bridgeInput.text === ""
                                text: "Bridge IP, e.g. 192.168.1.20"
                                font: bridgeInput.font
                                color: Theme.textTertiary
                            }
                        }
                    }

                    HueButton {
                        text: HueService.discovering ? "..." : "FIND"
                        busy: HueService.discovering
                        onClicked: HueService.discover()
                    }

                    HueButton {
                        text: "PAIR"
                        busy: HueService.pairState === "busy"
                        onClicked: {
                            HueService.setBridge(bridgeInput.text);
                            HueService.pair();
                        }
                    }
                }

                Text {
                    visible: HueService.foundBridges.length > 1
                    text: "Found: " + HueService.foundBridges.join(", ")
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontPx(10)
                    color: Theme.textTertiary
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
            }

            // Controls for the selected light
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.px(12)
                visible: HueService.paired && root.light !== null

                HueSlider {
                    visible: root.light !== null && root.light.hasBrightness
                    label: "BRIGHTNESS"
                    valueText: root.light ? Math.round(root.light.brightness) + "%" : ""
                    position: root.light && root.light.on ? root.light.brightness / 100 : 0
                    onMoved: function(p) { HueService.setBrightness(root.light.id, p * 100) }
                }

                HueSlider {
                    visible: root.light !== null && root.light.hasColorTemp
                    label: "WHITE TEMPERATURE"
                    valueText: root.light && root.light.mirek > 0 ? Math.round(1000000 / root.light.mirek) + " K" : "Color"
                    fillColor: Theme.accentBlue
                    // Warm (high mirek) on the left, cool on the right
                    position: root.light && root.light.mirek > 0
                        ? 1 - (root.light.mirek - root.light.mirekMin) / (root.light.mirekMax - root.light.mirekMin)
                        : 0
                    onMoved: function(p) {
                        HueService.setMirek(root.light.id, root.light.mirekMax - p * (root.light.mirekMax - root.light.mirekMin));
                    }
                }
            }

            // Other lights, tucked into an expander
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.px(4)
                visible: root.otherLights.length > 0 && root.light !== null

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Theme.px(28)
                    radius: Theme.corner(8)
                    color: expanderMouse.containsMouse ? Theme.overlay(0.06) : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.px(10)
                        anchors.rightMargin: Theme.px(10)

                        Text {
                            text: "OTHER LIGHTS (" + root.otherLights.length + ")"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontPx(10)
                            font.weight: Font.DemiBold
                            color: Theme.textTertiary
                            Layout.fillWidth: true
                        }

                        SvgIcon {
                            name: root.othersExpanded ? "chevron-up" : "chevron-down"
                            size: Theme.px(12)
                            color: Theme.textTertiary
                        }
                    }

                    MouseArea {
                        id: expanderMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.othersExpanded = !root.othersExpanded
                    }
                }

                // Clicking a row shows that lamp's controls; the dot turns it on or off
                Repeater {
                    model: root.othersExpanded ? root.otherLights : []

                    Rectangle {
                        readonly property bool favourite: modelData.id === HueService.favouriteId

                        Layout.fillWidth: true
                        Layout.preferredHeight: Theme.px(28)
                        radius: Theme.corner(8)
                        color: lightMouse.containsMouse ? Theme.overlay(0.06) : "transparent"
                        Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }

                        MouseArea {
                            id: lightMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: HueService.selectLight(modelData.id)
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.px(10)
                            anchors.rightMargin: Theme.px(6)
                            spacing: Theme.px(8)

                            SvgIcon {
                                name: "bulb"
                                size: Theme.px(12)
                                color: modelData.on ? root.hueColor : Theme.textTertiary
                            }

                            Text {
                                text: modelData.name
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontPx(11)
                                color: Theme.textSecondary
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            SvgIcon {
                                name: "pin"
                                size: Theme.px(11)
                                color: root.hueColor
                                visible: favourite
                            }

                            Rectangle {
                                Layout.preferredWidth: Theme.px(40)
                                Layout.preferredHeight: Theme.px(20)
                                radius: Theme.px(10)
                                color: modelData.on ? Qt.rgba(255/255, 159/255, 10/255, 0.25) : Theme.overlay(0.1)
                                Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.on ? "ON" : "OFF"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontPx(9)
                                    font.weight: Font.Bold
                                    color: modelData.on ? root.hueColor : Theme.textSecondary
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: HueService.toggle(modelData.id)
                                }
                            }
                        }
                    }
                }
            }

            // Disconnect from the bridge
            RowLayout {
                Layout.fillWidth: true
                visible: HueService.paired

                Text {
                    text: SettingsService.hueBridgeIp
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontPx(10)
                    color: Theme.textTertiary
                    Layout.fillWidth: true
                }

                HueButton {
                    text: "FORGET BRIDGE"
                    onClicked: HueService.unpair()
                }
            }
        }
    }
}
