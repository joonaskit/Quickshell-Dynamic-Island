import ".."
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    signal requestBack()
    signal requestClose()

    readonly property var tabs: ["Display", "Top bar", "Island", "Dock", "Launcher", "About"]
    property int currentTab: 0

    // Switches to a tab by its name in `tabs`; unknown names are ignored
    function showTab(name) {
        let idx = tabs.indexOf(name);
        if (idx < 0) return;
        searchInput.text = "";
        currentTab = idx;
    }
    readonly property bool hasSearchResults: displaySettings.hasMatches || topBarSettings.hasMatches || islandSettings.hasMatches
                                             || dockSettings.hasMatches || launcherSettings.hasMatches

    // Start from a clean search each time the settings card is opened
    onVisibleChanged: {
        if (!visible) searchInput.text = "";
    }

    readonly property real maxAllowedHeight: {
        let scrH = (Screen.height > 0) ? Screen.height : 1080;
        return Math.min(scrH - Theme.px(120), Theme.px(840));
    }

    readonly property real desiredHeight: headerColumn.implicitHeight + contentColumn.implicitHeight + bottomGrabberArea.height + 14 + Theme.px(28)
    readonly property bool needsScroll: desiredHeight > maxAllowedHeight

    implicitWidth: Theme.px(540)
    implicitHeight: Math.min(desiredHeight, maxAllowedHeight)

    // Fixed header: title bar, search box and category tabs
    ColumnLayout {
        id: headerColumn
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 14
        spacing: 14

        // Top Header: Back Button, Title with Icon, and Close Button
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            // Back Button (returns to Expanded Island View)
            Rectangle {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                radius: 16
                color: backMouse.containsMouse ? Theme.cardBackgroundHover : Theme.overlay(0.08)
                scale: backMouse.pressed ? 0.90 : (backMouse.containsMouse ? 1.05 : 1.0)

                Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }
                Behavior on scale { NumberAnimation { duration: Theme.animDurationTooltip; easing.type: Easing.OutCubic } }

                SvgIcon {
                    anchors.centerIn: parent
                    name: "chevron-left"
                    size: 16
                    color: backMouse.containsMouse ? Theme.textPrimary : Theme.textSecondary
                }

                MouseArea {
                    id: backMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.requestBack()
                }
            }

            // Settings Icon & Title
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    Layout.preferredWidth: 34
                    Layout.preferredHeight: 34
                    radius: 17
                    color: Theme.accentTint(0.22)

                    SvgIcon {
                        anchors.centerIn: parent
                        name: "settings"
                        size: 18
                        color: Theme.accent
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        text: "Settings"
                        font.family: Theme.fontDisplay
                        font.pixelSize: 16
                        font.weight: Font.Bold
                        color: Theme.textPrimary
                    }

                    Text {
                        text: "Preferences & Customization"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: Theme.textSecondary
                    }
                }
            }

            // Close Button (dismisses the island completely)
            Rectangle {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                radius: 14
                color: closeMouse.containsMouse ? Qt.rgba(255/255, 69/255, 58/255, 0.2) : "transparent"
                scale: closeMouse.pressed ? 0.90 : (closeMouse.containsMouse ? 1.05 : 1.0)

                Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }
                Behavior on scale { NumberAnimation { duration: Theme.animDurationTooltip; easing.type: Easing.OutCubic } }

                SvgIcon {
                    anchors.centerIn: parent
                    name: "close"
                    size: 14
                    color: closeMouse.containsMouse ? Theme.accentRed : Theme.textSecondary
                }

                MouseArea {
                    id: closeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.requestClose()
                }
            }
        }

        // Search box (filters rows across every category)
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            radius: 10
            color: Theme.overlay(searchInput.activeFocus ? 0.10 : 0.06)
            border.width: 1
            border.color: searchInput.activeFocus ? Theme.accentTint(0.5) : Theme.overlay(0.08)

            Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }
            Behavior on border.color { ColorAnimation { duration: Theme.animDurationFast } }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.IBeamCursor
                onClicked: searchInput.forceActiveFocus()
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 6
                spacing: 8

                SvgIcon {
                    name: "search"
                    size: 14
                    color: searchInput.activeFocus ? Theme.accent : Theme.textSecondary
                }

                TextInput {
                    id: searchInput
                    Layout.fillWidth: true
                    activeFocusOnTab: true
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    color: Theme.textPrimary
                    selectionColor: Theme.accentTint(0.4)
                    selectedTextColor: Theme.textPrimary
                    clip: true
                    selectByMouse: true
                    onTextChanged: {
                        SettingsSearch.query = text;
                        scrollContainer.contentY = 0;
                    }

                    Keys.onEscapePressed: function(event) {
                        if (text !== "") {
                            text = "";
                        } else {
                            root.requestBack();
                        }
                        event.accepted = true;
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: searchInput.text === ""
                        text: "Search settings"
                        font: searchInput.font
                        color: Theme.textTertiary
                    }
                }

                // Clear button
                Rectangle {
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 20
                    radius: 10
                    visible: searchInput.text !== ""
                    color: clearMouse.containsMouse ? Theme.overlay(0.14) : "transparent"

                    Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }

                    SvgIcon {
                        anchors.centerIn: parent
                        name: "close"
                        size: 11
                        color: clearMouse.containsMouse ? Theme.textPrimary : Theme.textSecondary
                    }

                    MouseArea {
                        id: clearMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            searchInput.text = "";
                            searchInput.forceActiveFocus();
                        }
                    }
                }
            }
        }

        // Category tabs (no tab is highlighted while searching)
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            radius: 8
            color: Theme.overlay(0.08)

            RowLayout {
                anchors.fill: parent
                anchors.margins: 2
                spacing: 2

                Repeater {
                    model: root.tabs

                    Rectangle {
                        id: tabBtn
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 6
                        readonly property bool isSelected: !SettingsSearch.active && root.currentTab === index
                        color: isSelected ? Theme.overlay(0.22) : (tabMouse.containsMouse ? Theme.overlay(0.06) : "transparent")

                        Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }

                        Text {
                            anchors.centerIn: parent
                            text: modelData
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.weight: tabBtn.isSelected ? Font.Bold : Font.Normal
                            color: tabBtn.isSelected ? Theme.textPrimary : Theme.textSecondary
                        }

                        MouseArea {
                            id: tabMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                searchInput.text = "";
                                root.currentTab = index;
                                scrollContainer.contentY = 0;
                            }
                        }
                    }
                }
            }
        }

        // Hairline Divider
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.overlay(0.08)
        }
    }

    // Smooth scrollable container
    Flickable {
        id: scrollContainer
        anchors.top: headerColumn.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: bottomGrabberArea.top
        contentWidth: width
        contentHeight: contentColumn.implicitHeight + 28
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: root.needsScroll

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            onWheel: function(wheel) {
                if (root.needsScroll) {
                    scrollContainer.contentY = Math.max(0, Math.min(scrollContainer.contentHeight - scrollContainer.height, scrollContainer.contentY - wheel.angleDelta.y));
                    scrollFadeTimer.restart();
                }
            }
        }

        ColumnLayout {
            id: contentColumn
            width: scrollContainer.width - 28
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 14
            spacing: 14

            // Categories: the active tab, or every category with matches while searching
            DisplaySettings {
                id: displaySettings
                visible: SettingsSearch.active ? hasMatches : root.currentTab === 0
            }
            TopBarSettings {
                id: topBarSettings
                visible: SettingsSearch.active ? hasMatches : root.currentTab === 1
            }
            IslandSettings {
                id: islandSettings
                visible: SettingsSearch.active ? hasMatches : root.currentTab === 2
            }
            DockSettings {
                id: dockSettings
                visible: SettingsSearch.active ? hasMatches : root.currentTab === 3
            }
            LauncherSettings {
                id: launcherSettings
                visible: SettingsSearch.active ? hasMatches : root.currentTab === 4
            }
            AboutSettings {
                visible: !SettingsSearch.active && root.currentTab === 5
            }

            // Empty search result
            Text {
                Layout.fillWidth: true
                Layout.topMargin: 10
                Layout.bottomMargin: 10
                visible: SettingsSearch.active && !root.hasSearchResults
                text: "No settings match \"" + SettingsSearch.query.trim() + "\""
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pixelSize: 12
                color: Theme.textSecondary
            }
        }
    }

    // Subtle Subtle fading scroll indicator (anchored strictly to card viewport, hidden when idle)
    Item {
        id: scrollTrack
        anchors.top: scrollContainer.top
        anchors.topMargin: 46
        anchors.bottom: scrollContainer.bottom
        anchors.bottomMargin: 8
        anchors.right: parent.right
        anchors.rightMargin: 8
        width: 3
        visible: root.needsScroll
        opacity: (scrollContainer.moving || scrollContainer.flicking || scrollFadeTimer.running) ? 1.0 : 0.0

        Behavior on opacity {
            NumberAnimation { duration: Theme.animDurationFast }
        }

        Rectangle {
            id: scrollThumb
            width: 3
            radius: 1.5
            color: Theme.overlay(0.35)
            y: Math.max(0, Math.min(scrollTrack.height - height, scrollContainer.visibleArea.yPosition * scrollTrack.height))
            height: Math.max(28, scrollContainer.visibleArea.heightRatio * scrollTrack.height)
        }
    }

    Timer {
        id: scrollFadeTimer
        interval: 800
        repeat: false
    }

    // Bottom Grabber Pill
    Item {
        id: bottomGrabberArea
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 20

        Rectangle {
            anchors.centerIn: parent
            width: 38
            height: 4
            radius: 2
            color: grabberMouse.containsMouse ? Theme.overlay(0.45) : Theme.overlay(0.25)

            Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }
        }

        MouseArea {
            id: grabberMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.requestClose()
        }
    }
}
