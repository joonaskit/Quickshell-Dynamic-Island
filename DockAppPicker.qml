import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell

Item {
    id: root

    property bool isOpen: false
    property string searchText: ""

    signal closed()

    visible: opacity > 0.001
    opacity: isOpen ? 1.0 : 0.0
    scale: isOpen ? 1.0 : 0.92
    transformOrigin: Item.Bottom

    Behavior on opacity {
        NumberAnimation { duration: Theme.animDurationFast; easing.type: Easing.OutCubic }
    }
    Behavior on scale {
        NumberAnimation { duration: Theme.animDuration; easing.type: Theme.animEasing; easing.overshoot: Theme.animEntranceOvershoot }
    }

    width: 380
    height: 420

    onIsOpenChanged: {
        if (isOpen) {
            DockService.updateInstalledApps();
            searchInput.text = "";
            root.searchText = "";
            appListView.currentIndex = 0;
            searchInput.forceActiveFocus();
            focusTimer.restart();
        } else {
            searchInput.text = "";
            root.searchText = "";
            focusTimer.stop();
        }
    }

    Timer {
        id: focusTimer
        interval: 40
        repeat: false
        onTriggered: {
            if (root.isOpen) {
                searchInput.forceActiveFocus();
                searchInput.selectAll();
            }
        }
    }

    function launchCurrentApp() {
        let list = appListView.model;
        if (list && list.length > 0) {
            let idx = appListView.currentIndex;
            if (idx < 0 || idx >= list.length) idx = 0;
            let targetApp = list[idx];
            if (targetApp) {
                DockService.activateOrLaunch(targetApp);
                root.isOpen = false;
                root.closed();
            }
        }
    }

    // Background card with blur and subtle border
    Rectangle {
        id: bg
        anchors.fill: parent
        radius: 18
        color: "#1c1c1e"
        border.color: Theme.dockBorder
        border.width: Theme.dockShowBorder ? 1 : 0

        // Clicking anywhere on picker background returns focus to search
        MouseArea {
            anchors.fill: parent
            z: -1
            onClicked: {
                searchInput.forceActiveFocus();
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        // Header with title, KRunner button, and close button
        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "Applications"
                font.family: Theme.fontDisplay
                font.pixelSize: 17
                font.weight: Font.DemiBold
                color: Theme.textPrimary
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                Layout.preferredHeight: 24
                Layout.preferredWidth: krunnerRow.implicitWidth + 14
                radius: 12
                color: krunnerMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.08)

                Row {
                    id: krunnerRow
                    anchors.centerIn: parent
                    spacing: 5

                    SvgIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "bolt"
                        size: 11
                        color: Theme.accentBlue
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "KRunner"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        color: Theme.accentBlue
                    }
                }

                MouseArea {
                    id: krunnerMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        DockService.openLaunchpad();
                        root.isOpen = false;
                        root.closed();
                    }
                }
            }

            Rectangle {
                width: 26
                height: 26
                radius: 13
                color: closeHover.containsMouse ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.08)

                SvgIcon {
                    anchors.centerIn: parent
                    name: "close"
                    size: 12
                    color: Theme.textSecondary
                }

                MouseArea {
                    id: closeHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.isOpen = false;
                        root.closed();
                    }
                }
            }
        }

        // Search Input Bar
        Rectangle {
            Layout.fillWidth: true
            height: 34
            radius: 9
            color: Qt.rgba(1, 1, 1, 0.08)
            border.color: searchInput.activeFocus ? Theme.accentBlue : Qt.rgba(1, 1, 1, 0.08)
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 8
                spacing: 8

                SvgIcon {
                    name: "search"
                    size: 14
                    color: searchInput.activeFocus ? Theme.accentBlue : Theme.textSecondary
                }

                TextInput {
                    id: searchInput
                    Layout.fillWidth: true
                    focus: true
                    activeFocusOnTab: true
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    color: Theme.textPrimary
                    selectionColor: Qt.rgba(0.04, 0.52, 1, 0.4)
                    selectedTextColor: Theme.textPrimary
                    clip: true
                    selectByMouse: true
                    cursorVisible: activeFocus
                    onTextChanged: {
                        root.searchText = text.toLowerCase();
                        appListView.currentIndex = 0;
                    }

                    onAccepted: {
                        root.launchCurrentApp();
                    }

                    Keys.onEscapePressed: function(event) {
                        root.isOpen = false;
                        root.closed();
                        event.accepted = true;
                    }

                    Keys.onDownPressed: function(event) {
                        if (appListView.count > 0) {
                            appListView.currentIndex = Math.min(appListView.count - 1, appListView.currentIndex + 1);
                            appListView.positionViewAtIndex(appListView.currentIndex, ListView.Contain);
                        }
                        event.accepted = true;
                    }

                    Keys.onUpPressed: function(event) {
                        if (appListView.count > 0) {
                            appListView.currentIndex = Math.max(0, appListView.currentIndex - 1);
                            appListView.positionViewAtIndex(appListView.currentIndex, ListView.Contain);
                        }
                        event.accepted = true;
                    }

                    Text {
                        anchors.fill: parent
                        text: "Search installed apps..."
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        color: Theme.textTertiary
                        visible: !searchInput.text && !searchInput.activeFocus
                    }
                }

                // Clear button when text is entered
                Item {
                    Layout.preferredWidth: 18
                    Layout.preferredHeight: 18
                    visible: searchInput.text.length > 0

                    Rectangle {
                        anchors.fill: parent
                        radius: 9
                        color: clearMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.12)

                        SvgIcon {
                            anchors.centerIn: parent
                            name: "close"
                            size: 10
                            color: Theme.textSecondary
                        }

                        MouseArea {
                            id: clearMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                searchInput.text = "";
                                root.searchText = "";
                                searchInput.forceActiveFocus();
                            }
                        }
                    }
                }
            }
        }

        // Applications List View
        ListView {
            id: appListView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 4
            currentIndex: 0
            boundsBehavior: Flickable.StopAtBounds

            model: {
                if (!root.searchText || root.searchText.trim() === "") {
                    return DockService.installedApps;
                }
                return DockService.installedApps.filter(function(app) {
                    return app.name.toLowerCase().indexOf(root.searchText) >= 0 ||
                           (app.genericName && app.genericName.toLowerCase().indexOf(root.searchText) >= 0);
                });
            }

            delegate: Rectangle {
                id: itemDelegate
                width: appListView.width
                height: 42
                radius: 8
                readonly property bool isSelected: index === appListView.currentIndex
                color: isSelected ? Qt.rgba(0.04, 0.52, 1, 0.22) : (itemMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : "transparent")
                border.color: isSelected ? Qt.rgba(0.04, 0.52, 1, 0.5) : "transparent"
                border.width: isSelected ? 1 : 0

                readonly property bool pinned: DockService.isPinned(modelData.id)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 10

                    // App Icon
                    Image {
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        source: DockService.resolveIcon(modelData.icon)
                        sourceSize.width: 64
                        sourceSize.height: 64
                        fillMode: Image.PreserveAspectFit
                        mipmap: true
                        smooth: true
                    }

                    // App Title & Generic Name
                    Column {
                        Layout.fillWidth: true
                        spacing: 1

                        Text {
                            text: modelData.name
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            font.weight: isSelected ? Font.DemiBold : Font.Medium
                            color: Theme.textPrimary
                            elide: Text.ElideRight
                            width: parent.width
                        }

                        Text {
                            text: modelData.genericName || modelData.comment || ""
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            color: isSelected ? Qt.rgba(1, 1, 1, 0.8) : Theme.textSecondary
                            elide: Text.ElideRight
                            width: parent.width
                            visible: text.length > 0
                        }
                    }

                    // Pin / Unpin Action Button
                    Rectangle {
                        Layout.preferredWidth: 64
                        Layout.preferredHeight: 24
                        radius: 6
                        color: pinBtnMouse.containsMouse ? (pinned ? Qt.rgba(1, 0.3, 0.3, 0.25) : Qt.rgba(0.04, 0.52, 1, 0.25)) : (pinned ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0.04, 0.52, 1, 0.15))
                        border.color: pinned ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0.04, 0.52, 1, 0.4)
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: pinned ? "Pinned" : "+ Pin"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            color: pinned ? Theme.textSecondary : Theme.accentBlue
                        }

                        MouseArea {
                            id: pinBtnMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (pinned) {
                                    DockService.unpinApp(modelData.id);
                                } else {
                                    DockService.pinApp(modelData);
                                }
                            }
                        }
                    }
                }

                // Click to launch
                MouseArea {
                    id: itemMouse
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.rightMargin: 70
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: {
                        appListView.currentIndex = index;
                    }
                    onClicked: {
                        DockService.activateOrLaunch(modelData);
                        root.isOpen = false;
                        root.closed();
                    }
                }
            }
        }

        // Empty state when search yields no matches
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: appListView.count === 0

            Column {
                anchors.centerIn: parent
                spacing: 8

                SvgIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: "search"
                    size: 32
                    color: Qt.rgba(1, 1, 1, 0.2)
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "No applications found"
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    color: Theme.textSecondary
                }
            }
        }
    }
}
