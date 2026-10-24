import ".."
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

// Settings: a floating panel styled like the clipboard history window. It stays open
// until it is closed, can be dragged by its header and only takes keyboard focus when
// clicked. Opened with SettingsService.requestOpenSettings. Created once per screen;
// only the active screen shows it.
PanelWindow {
    id: window

    required property var modelData
    screen: modelData

    color: "transparent"
    implicitWidth: Theme.px(820)
    implicitHeight: {
        let scrH = (window.screen && window.screen.height > 0) ? window.screen.height : 1080;
        return Math.min(scrH - Theme.px(80), Theme.px(640));
    }
    // Placed with margins from the top left corner so it can be moved
    anchors {
        top: true
        left: true
    }
    margins {
        left: Math.max(0, SettingsService.windowX)
        top: Math.max(0, SettingsService.windowY)
    }
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "quickshell-settings"
    WlrLayershell.keyboardFocus: window.shown ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    readonly property bool isThisScreenActive: {
        if (!WindowService.activeScreen) return true;
        if (!window.screen || !window.screen.name) return true;
        return WindowService.activeScreen === window.screen.name;
    }
    readonly property bool shown: SettingsService.windowOpen && isThisScreenActive
    visible: shown || card.opacity > 0.01

    readonly property var tabs: ["Display", "Top bar", "Island", "Dock", "Launcher", "Widgets", "Shortcuts", "About"]
    property int currentTab: 0

    readonly property bool hasSearchResults: displaySettings.hasMatches || topBarSettings.hasMatches || islandSettings.hasMatches
                                             || dockSettings.hasMatches || launcherSettings.hasMatches || widgetsSettings.hasMatches || shortcutsSettings.hasMatches

    // Switches to a tab by its name in `tabs`; unknown names are ignored
    function showTab(name) {
        let idx = tabs.indexOf(name);
        if (idx < 0) return;
        searchInput.text = "";
        window.currentTab = idx;
        scrollContainer.contentY = 0;
    }

    // Moves the window, keeping it on its screen
    function moveBy(dx, dy) {
        let maxX = Math.max(0, (window.screen ? window.screen.width : 1920) - window.width);
        let maxY = Math.max(0, (window.screen ? window.screen.height : 1080) - window.height);
        SettingsService.windowX = Math.max(0, Math.min(maxX, SettingsService.windowX + dx));
        SettingsService.windowY = Math.max(0, Math.min(maxY, SettingsService.windowY + dy));
    }

    function close() {
        SettingsService.windowOpen = false;
    }

    // Start from a clean search each time the window is opened
    onShownChanged: {
        if (!shown) return;
        if (SettingsService.windowX < 0 && window.screen) {
            SettingsService.windowX = Math.round((window.screen.width - window.width) / 2);
            SettingsService.windowY = Math.round((window.screen.height - window.height) / 2);
        }
        searchInput.text = "";
        Qt.callLater(() => searchInput.forceActiveFocus());
    }

    Connections {
        target: SettingsService
        function onOpenSettingsRequested(tab) {
            if (tab) window.showTab(tab);
        }
    }

    // Small pill button, as in the clipboard window
    component ActionButton: Rectangle {
        id: btn
        property string iconName: ""
        signal clicked()

        Layout.preferredHeight: Theme.px(28)
        Layout.preferredWidth: Theme.px(28)
        radius: Theme.corner(14)
        color: btnMouse.containsMouse ? Theme.overlay(0.16) : Theme.overlay(0.08)
        scale: btnMouse.pressed ? 0.94 : 1.0
        Behavior on color { ColorAnimation { duration: Theme.animDurationTooltip } }
        Behavior on scale { NumberAnimation { duration: Theme.animDurationTooltip; easing.type: Easing.OutCubic } }

        SvgIcon {
            anchors.centerIn: parent
            name: btn.iconName
            size: Theme.px(12)
            color: Theme.textPrimary
        }

        MouseArea {
            id: btnMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }
    }

    Rectangle {
        id: card
        anchors.fill: parent
        radius: Theme.corner(20)
        color: Theme.cardBackground
        border.width: 1
        border.color: Theme.overlay(0.1)
        opacity: window.shown ? 1 : 0
        scale: window.shown ? 1 : 0.96
        Behavior on opacity { NumberAnimation { duration: Theme.animDurationFast } }
        Behavior on scale { NumberAnimation { duration: Theme.animDurationFast; easing.type: Easing.OutCubic } }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.px(16)
            spacing: Theme.px(10)

            // Header, which also moves the window when dragged
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: Theme.px(30)

                MouseArea {
                    property real pressX: 0
                    property real pressY: 0
                    anchors.fill: parent
                    cursorShape: Qt.SizeAllCursor
                    onPressed: mouse => {
                        pressX = mouse.x;
                        pressY = mouse.y;
                    }
                    onPositionChanged: mouse => {
                        if (pressed) window.moveBy(mouse.x - pressX, mouse.y - pressY);
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    spacing: Theme.px(8)

                    SvgIcon {
                        name: "settings"
                        size: Theme.px(16)
                        color: Theme.accent
                    }

                    Text {
                        text: "Settings"
                        font.family: Theme.fontDisplay
                        font.pixelSize: Theme.fontPx(15)
                        font.weight: Font.Bold
                        color: Theme.textPrimary
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Preferences & Customization"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontPx(11)
                        color: Theme.textTertiary
                        elide: Text.ElideRight
                    }

                    ActionButton {
                        iconName: "close"
                        onClicked: window.close()
                    }
                }
            }

            // Search (filters rows across every category)
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Theme.px(34)
                radius: Theme.corner(9)
                color: Theme.overlay(0.08)
                border.width: 1
                border.color: searchInput.activeFocus ? Theme.accent : Theme.overlay(0.08)

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.IBeamCursor
                    onClicked: searchInput.forceActiveFocus()
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.px(10)
                    anchors.rightMargin: Theme.px(8)
                    spacing: Theme.px(8)

                    SvgIcon {
                        name: "search"
                        size: Theme.px(14)
                        color: searchInput.activeFocus ? Theme.accent : Theme.textSecondary
                    }

                    TextInput {
                        id: searchInput
                        Layout.fillWidth: true
                        activeFocusOnTab: true
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontPx(13)
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
                                window.close();
                            }
                            event.accepted = true;
                        }

                        Text {
                            anchors.fill: parent
                            text: "Search settings..."
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontPx(13)
                            color: Theme.textTertiary
                            visible: !searchInput.text
                        }
                    }

                    // Clear button
                    Rectangle {
                        Layout.preferredWidth: Theme.px(20)
                        Layout.preferredHeight: Theme.px(20)
                        radius: Theme.corner(10)
                        visible: searchInput.text !== ""
                        color: clearMouse.containsMouse ? Theme.overlay(0.14) : "transparent"

                        Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }

                        SvgIcon {
                            anchors.centerIn: parent
                            name: "close"
                            size: Theme.px(11)
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

            // Categories and the active page
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Theme.px(12)

                // Category list (nothing is highlighted while searching)
                Rectangle {
                    Layout.preferredWidth: Theme.px(170)
                    Layout.fillHeight: true
                    radius: Theme.corner(12)
                    color: Theme.overlay(0.04)

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.px(6)
                        spacing: Theme.px(2)

                        Repeater {
                            model: window.tabs

                            Rectangle {
                                id: tabBtn
                                required property var modelData
                                required property int index
                                readonly property bool isSelected: !SettingsSearch.active && window.currentTab === index
                                Layout.fillWidth: true
                                Layout.preferredHeight: Theme.px(32)
                                radius: Theme.corner(8)
                                color: isSelected ? Theme.accentTint(0.25) : (tabMouse.containsMouse ? Theme.overlay(0.08) : "transparent")
                                Behavior on color { ColorAnimation { duration: Theme.animDurationTooltip } }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: Theme.px(12)
                                    text: tabBtn.modelData
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontPx(12)
                                    font.weight: tabBtn.isSelected ? Font.DemiBold : Font.Normal
                                    color: tabBtn.isSelected ? Theme.accentText : Theme.textSecondary
                                }

                                MouseArea {
                                    id: tabMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: window.showTab(tabBtn.modelData)
                                }
                            }
                        }

                        Item { Layout.fillHeight: true }
                    }
                }

                // Page, scrolled when taller than the window
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    readonly property bool needsScroll: scrollContainer.contentHeight > scrollContainer.height

                    Flickable {
                        id: scrollContainer
                        anchors.fill: parent
                        contentWidth: width
                        contentHeight: contentColumn.implicitHeight + Theme.px(8)
                        boundsBehavior: Flickable.StopAtBounds
                        interactive: parent.needsScroll

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.NoButton
                            onWheel: function(wheel) {
                                if (scrollContainer.interactive) {
                                    scrollContainer.contentY = Math.max(0, Math.min(scrollContainer.contentHeight - scrollContainer.height, scrollContainer.contentY - wheel.angleDelta.y));
                                    scrollFadeTimer.restart();
                                }
                            }
                        }

                        ColumnLayout {
                            id: contentColumn
                            width: scrollContainer.width - Theme.px(14)
                            spacing: 14

                            // Categories: the active tab, or every category with matches while searching
                            DisplaySettings {
                                id: displaySettings
                                visible: SettingsSearch.active ? hasMatches : window.currentTab === 0
                            }
                            TopBarSettings {
                                id: topBarSettings
                                visible: SettingsSearch.active ? hasMatches : window.currentTab === 1
                            }
                            IslandSettings {
                                id: islandSettings
                                visible: SettingsSearch.active ? hasMatches : window.currentTab === 2
                            }
                            DockSettings {
                                id: dockSettings
                                visible: SettingsSearch.active ? hasMatches : window.currentTab === 3
                            }
                            LauncherSettings {
                                id: launcherSettings
                                visible: SettingsSearch.active ? hasMatches : window.currentTab === 4
                            }
                            WidgetsSettings {
                                id: widgetsSettings
                                visible: SettingsSearch.active ? hasMatches : window.currentTab === 5
                            }
                            ShortcutsSettings {
                                id: shortcutsSettings
                                visible: SettingsSearch.active ? hasMatches : window.currentTab === 6
                            }
                            AboutSettings {
                                visible: !SettingsSearch.active && window.currentTab === 7
                            }

                            // Empty search result
                            Text {
                                Layout.fillWidth: true
                                Layout.topMargin: 10
                                Layout.bottomMargin: 10
                                visible: SettingsSearch.active && !window.hasSearchResults
                                text: "No settings match \"" + SettingsSearch.query.trim() + "\""
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontPx(12)
                                color: Theme.textSecondary
                            }
                        }
                    }

                    // Fading scroll indicator, hidden when idle
                    Item {
                        id: scrollTrack
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.right: parent.right
                        width: 3
                        visible: parent.needsScroll
                        opacity: (scrollContainer.moving || scrollContainer.flicking || scrollFadeTimer.running) ? 1.0 : 0.0

                        Behavior on opacity {
                            NumberAnimation { duration: Theme.animDurationFast }
                        }

                        Rectangle {
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
                }
            }
        }
    }
}
