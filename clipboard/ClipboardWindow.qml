import ".."
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../services/clipboardHistory.js" as History

// Clipboard history: a floating panel that stays open until it is closed (see the
// "clipboard" IPC handler in shell.qml). It can be dragged by its header and only
// takes keyboard focus when clicked. Created once per screen; only the active
// screen shows it.
PanelWindow {
    id: window

    required property var modelData
    screen: modelData

    color: "transparent"
    implicitWidth: Theme.px(760)
    implicitHeight: Theme.px(500)
    // Placed with margins from the top left corner so it can be moved
    anchors {
        top: true
        left: true
    }
    margins {
        left: Math.max(0, ClipboardService.windowX)
        top: Math.max(0, ClipboardService.windowY)
    }
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "quickshell-clipboard"
    WlrLayershell.keyboardFocus: window.shown ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    readonly property bool isThisScreenActive: {
        if (!WindowService.activeScreen) return true;
        if (!window.screen || !window.screen.name) return true;
        return WindowService.activeScreen === window.screen.name;
    }
    readonly property bool shown: ClipboardService.windowOpen && isThisScreenActive
    visible: shown || card.opacity > 0.01

    property string filter: "all"
    property string searchText: ""
    // Credential-like entries stay hidden until revealed; this is the revealed one
    property int revealedId: -1
    // Refreshed while shown so the ages stay current
    property double nowMs: Date.now()

    readonly property var entries: History.view(ClipboardService.history, window.searchText, window.filter)
    readonly property var selected: entries.length > 0 && list.currentIndex >= 0 && list.currentIndex < entries.length ? entries[list.currentIndex] : null
    readonly property string home: Quickshell.env("HOME") || ""
    readonly property bool selectedHidden: selected !== null && selected.sensitive && window.revealedId !== selected.id

    readonly property var filters: [
        { "label": "All", "value": "all" },
        { "label": "Text", "value": "text" },
        { "label": "Links", "value": "url" },
        { "label": "Images", "value": "image" },
        { "label": "Files", "value": "files" },
        { "label": "Pinned", "value": "pinned" }
    ]

    // [label, value] rows describing an entry
    function metadata(e) {
        let type = e.type === "image" ? "Image (" + e.mime + ")" : (e.type === "files" ? (e.files.length === 1 ? "File" : e.files.length + " files") : (e.kind === "url" ? "Link" : "Text"));
        let size = e.type === "text" ? History.formatSize(e.size) + " · " + e.chars + " chars · " + e.lines + (e.lines === 1 ? " line" : " lines")
            : (e.type === "image" ? History.formatSize(e.size) + (detailImage.status === Image.Ready ? " · " + detailImage.implicitWidth + "×" + detailImage.implicitHeight : "") : "");
        let rows = [
            ["Type", type],
            ["Copied", History.formatAge(e.time, window.nowMs) + (e.count > 1 ? " (" + e.count + " times)" : "")],
            ["First seen", Qt.formatDateTime(new Date(e.firstTime), "d MMM, hh:mm:ss")]
        ];
        if (size !== "") rows.splice(1, 0, ["Size", size]);
        rows.push(e.type === "files" ? ["Folder", History.displayDir(e.dir, window.home)] : ["Source", e.appTitle !== "" ? e.appTitle : "Unknown"]);
        return rows;
    }

    // Moves the window, keeping it on its screen
    function moveBy(dx, dy) {
        let maxX = Math.max(0, (window.screen ? window.screen.width : 1920) - window.width);
        let maxY = Math.max(0, (window.screen ? window.screen.height : 1080) - window.height);
        ClipboardService.windowX = Math.max(0, Math.min(maxX, ClipboardService.windowX + dx));
        ClipboardService.windowY = Math.max(0, Math.min(maxY, ClipboardService.windowY + dy));
    }

    onShownChanged: {
        if (!shown) return;
        if (ClipboardService.windowX < 0 && window.screen) {
            ClipboardService.windowX = Math.round((window.screen.width - window.width) / 2);
            ClipboardService.windowY = Math.round((window.screen.height - window.height) / 2);
        }
        searchInput.text = "";
        window.filter = "all";
        window.revealedId = -1;
        window.nowMs = Date.now();
        list.currentIndex = 0;
        Qt.callLater(() => searchInput.forceActiveFocus());
    }
    onEntriesChanged: {
        if (list.currentIndex >= entries.length) list.currentIndex = Math.max(0, entries.length - 1);
    }
    onSelectedChanged: {
        if (selected === null || selected.id !== window.revealedId) window.revealedId = -1;
    }

    Timer {
        interval: 15000
        running: window.shown
        repeat: true
        onTriggered: window.nowMs = Date.now()
    }

    function close() {
        ClipboardService.windowOpen = false;
    }

    // Brief confirmation shown in the header
    property string flash: ""

    Timer {
        id: flashTimer
        interval: 1500
        onTriggered: window.flash = ""
    }

    function copySelected() {
        if (!window.selected) return;
        ClipboardService.copyEntry(window.selected.id);
        window.flash = "Copied to clipboard";
        flashTimer.restart();
    }

    function select(id) {
        let i = window.entries.findIndex(e => e.id === id);
        if (i !== -1) list.currentIndex = i;
    }

    function togglePinSelected() {
        if (!window.selected) return;
        let id = window.selected.id;
        ClipboardService.togglePinned(id);
        Qt.callLater(() => window.select(id));
    }

    function removeSelected() {
        if (window.selected) ClipboardService.removeEntry(window.selected.id);
    }

    function toggleReveal() {
        if (!window.selected || !window.selected.sensitive) return;
        window.revealedId = window.revealedId === window.selected.id ? -1 : window.selected.id;
    }

    function cycleFilter() {
        let i = window.filters.findIndex(f => f.value === window.filter);
        window.filter = window.filters[(i + 1) % window.filters.length].value;
        list.currentIndex = 0;
    }

    function move(delta) {
        if (list.count === 0) return;
        list.currentIndex = Math.max(0, Math.min(list.count - 1, list.currentIndex + delta));
        list.positionViewAtIndex(list.currentIndex, ListView.Contain);
    }

    // Small pill button used for the actions
    component ActionButton: Rectangle {
        id: btn
        property string text: ""
        property string iconName: ""
        property bool danger: false
        // Shown pressed in, e.g. for a toggle that is on
        property bool active: false
        signal clicked()

        Layout.preferredHeight: Theme.px(28)
        Layout.preferredWidth: btnRow.implicitWidth + Theme.px(20)
        radius: Theme.corner(14)
        color: active ? Theme.accentTint(0.3)
            : btnMouse.containsMouse
            ? (danger ? Qt.rgba(1, 69 / 255, 58 / 255, 0.24) : Theme.overlay(0.16))
            : (danger ? Qt.rgba(1, 69 / 255, 58 / 255, 0.12) : Theme.overlay(0.08))
        scale: btnMouse.pressed ? 0.94 : 1.0
        Behavior on color { ColorAnimation { duration: Theme.animDurationTooltip } }
        Behavior on scale { NumberAnimation { duration: Theme.animDurationTooltip; easing.type: Easing.OutCubic } }

        RowLayout {
            id: btnRow
            anchors.centerIn: parent
            spacing: Theme.px(6)

            SvgIcon {
                visible: btn.iconName !== ""
                name: btn.iconName
                size: Theme.px(12)
                color: btn.danger ? Theme.accentRed : Theme.textPrimary
            }

            Text {
                visible: btn.text !== ""
                text: btn.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontPx(11)
                font.weight: Font.DemiBold
                color: btn.danger ? Theme.accentRed : Theme.textPrimary
            }
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

        // A click anywhere on the card gives the search field the keyboard
        MouseArea {
            anchors.fill: parent
            onPressed: mouse => {
                searchInput.forceActiveFocus();
                mouse.accepted = false;
            }
        }

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
                        name: "clipboard"
                        size: Theme.px(16)
                        color: Theme.accent
                    }

                    Text {
                        text: "Clipboard history"
                        font.family: Theme.fontDisplay
                        font.pixelSize: Theme.fontPx(15)
                        font.weight: Font.Bold
                        color: Theme.textPrimary
                    }

                    Text {
                        Layout.fillWidth: true
                        text: window.flash !== "" ? window.flash
                            : (ClipboardService.incognito ? "Incognito: new copies are not recorded"
                            : "Kept in memory only, gone when the shell stops")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontPx(11)
                        color: window.flash !== "" ? Theme.accentGreen : (ClipboardService.incognito ? Theme.accentYellowStrong : Theme.textTertiary)
                        elide: Text.ElideRight
                    }

                    ActionButton {
                        text: "Incognito"
                        iconName: "lock"
                        active: ClipboardService.incognito
                        onClicked: ClipboardService.incognito = !ClipboardService.incognito
                    }

                    ActionButton {
                        text: "Clear"
                        iconName: "trash"
                        danger: true
                        onClicked: ClipboardService.clearClipboard()
                    }

                    ActionButton {
                        Layout.preferredWidth: Theme.px(28)
                        iconName: "close"
                        onClicked: window.close()
                    }
                }
            }

            // Search
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Theme.px(34)
                radius: Theme.corner(9)
                color: Theme.overlay(0.08)
                border.width: 1
                border.color: searchInput.activeFocus ? Theme.accent : Theme.overlay(0.08)

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
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontPx(13)
                        color: Theme.textPrimary
                        selectionColor: Theme.accentTint(0.4)
                        selectedTextColor: Theme.textPrimary
                        clip: true
                        selectByMouse: true
                        onTextChanged: {
                            window.searchText = text;
                            list.currentIndex = 0;
                        }
                        onAccepted: window.copySelected()

                        Keys.onPressed: event => {
                            let ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
                            if (event.key === Qt.Key_Escape) {
                                window.close();
                            } else if (event.key === Qt.Key_Down) {
                                window.move(1);
                            } else if (event.key === Qt.Key_Up) {
                                window.move(-1);
                            } else if (event.key === Qt.Key_PageDown) {
                                window.move(6);
                            } else if (event.key === Qt.Key_PageUp) {
                                window.move(-6);
                            } else if (event.key === Qt.Key_Tab) {
                                window.cycleFilter();
                            } else if (ctrl && event.key === Qt.Key_P) {
                                window.togglePinSelected();
                            } else if (ctrl && event.key === Qt.Key_R) {
                                window.toggleReveal();
                            } else if (ctrl && event.key === Qt.Key_Delete) {
                                window.removeSelected();
                            } else {
                                return;
                            }
                            event.accepted = true;
                        }

                        Text {
                            anchors.fill: parent
                            text: "Search history..."
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontPx(13)
                            color: Theme.textTertiary
                            visible: !searchInput.text
                        }
                    }
                }
            }

            // Filters
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.px(6)

                Repeater {
                    model: window.filters

                    Rectangle {
                        id: chip
                        required property var modelData
                        readonly property bool active: window.filter === modelData.value
                        Layout.preferredHeight: Theme.px(24)
                        Layout.preferredWidth: chipText.implicitWidth + Theme.px(20)
                        radius: Theme.corner(12)
                        color: active ? Theme.accentTint(0.25) : (chipMouse.containsMouse ? Theme.overlay(0.1) : Theme.overlay(0.05))
                        Behavior on color { ColorAnimation { duration: Theme.animDurationTooltip } }

                        Text {
                            id: chipText
                            anchors.centerIn: parent
                            text: chip.modelData.label
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontPx(11)
                            font.weight: chip.active ? Font.DemiBold : Font.Normal
                            color: chip.active ? Theme.accentText : Theme.textSecondary
                        }

                        MouseArea {
                            id: chipMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                window.filter = chip.modelData.value;
                                list.currentIndex = 0;
                                searchInput.forceActiveFocus();
                            }
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: window.entries.length + (window.entries.length === 1 ? " item" : " items")
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontPx(11)
                    color: Theme.textTertiary
                }
            }

            // List and details
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Theme.px(12)

                ListView {
                    id: list
                    Layout.preferredWidth: Theme.px(300)
                    Layout.fillHeight: true
                    clip: true
                    spacing: Theme.px(2)
                    model: window.entries
                    boundsBehavior: Flickable.StopAtBounds
                    highlightMoveDuration: 0

                    delegate: Rectangle {
                        id: row
                        required property var modelData
                        required property int index
                        readonly property string thumb: History.thumbPath(modelData)
                        width: ListView.view.width
                        height: Theme.px(46)
                        radius: Theme.corner(10)
                        color: ListView.isCurrentItem ? Theme.accentTint(0.22) : (rowMouse.containsMouse ? Theme.overlay(0.06) : "transparent")

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.px(8)
                            anchors.rightMargin: Theme.px(8)
                            spacing: Theme.px(8)

                            Rectangle {
                                Layout.preferredWidth: Theme.px(28)
                                Layout.preferredHeight: Theme.px(28)
                                radius: Theme.corner(8)
                                color: Theme.overlay(0.08)

                                SvgIcon {
                                    anchors.centerIn: parent
                                    visible: row.modelData.sensitive
                                    name: "lock"
                                    size: Theme.px(12)
                                    color: Theme.accentYellowStrong
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: !row.modelData.sensitive && row.thumb === ""
                                    text: row.modelData.kind === "url" ? "URL" : (row.modelData.kind === "files" ? "File" : (row.modelData.kind === "image" ? "Img" : "Aa"))
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontPx(row.modelData.kind === "text" ? 11 : 9)
                                    font.weight: Font.Bold
                                    color: row.modelData.kind === "text" ? Theme.textSecondary : Theme.accentText
                                }

                                Image {
                                    anchors.fill: parent
                                    anchors.margins: 1
                                    visible: row.thumb !== "" && status === Image.Ready
                                    source: row.thumb !== "" ? History.fileUrl(row.thumb) : ""
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    sourceSize.width: 56
                                    sourceSize.height: 56
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: Theme.px(1)

                                Text {
                                    Layout.fillWidth: true
                                    text: row.modelData.sensitive ? "••••••••  looks like a credential" : History.label(row.modelData, 70)
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontPx(12)
                                    color: row.modelData.sensitive ? Theme.textTertiary : Theme.textPrimary
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: (row.modelData.type === "files" ? History.displayDir(row.modelData.dir, window.home) + " · "
                                        : (row.modelData.appTitle !== "" ? row.modelData.appTitle + " · " : "")) + History.formatAge(row.modelData.time, window.nowMs)
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontPx(10)
                                    color: Theme.textTertiary
                                    elide: Text.ElideRight
                                }
                            }

                            SvgIcon {
                                visible: row.modelData.pinned
                                name: "pin"
                                size: Theme.px(11)
                                color: Theme.accent
                            }

                            Text {
                                visible: row.modelData.count > 1
                                text: "×" + row.modelData.count
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontPx(10)
                                color: Theme.textTertiary
                            }
                        }

                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                list.currentIndex = row.index;
                                searchInput.forceActiveFocus();
                            }
                            onDoubleClicked: {
                                list.currentIndex = row.index;
                                window.copySelected();
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: list.count === 0
                        text: window.searchText !== "" || window.filter !== "all" ? "No matches" : "Nothing copied yet"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontPx(12)
                        color: Theme.textTertiary
                    }
                }

                // Details of the selected entry
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Theme.corner(12)
                    color: Theme.overlay(0.04)
                    border.width: 1
                    border.color: Theme.overlay(0.06)

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.px(12)
                        spacing: Theme.px(8)
                        visible: window.selected !== null

                        // Content
                        Flickable {
                            id: contentFlick
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            contentWidth: width
                            contentHeight: contentColumn.implicitHeight
                            boundsBehavior: Flickable.StopAtBounds

                            Column {
                                id: contentColumn
                                width: contentFlick.width
                                spacing: Theme.px(8)

                                Image {
                                    id: detailImage
                                    readonly property string thumb: window.selected === null ? "" : History.thumbPath(window.selected)
                                    width: parent.width
                                    height: status === Image.Ready ? Math.min(Theme.px(220), width * implicitHeight / Math.max(1, implicitWidth)) : 0
                                    visible: status === Image.Ready
                                    source: thumb !== "" ? History.fileUrl(thumb) : ""
                                    fillMode: Image.PreserveAspectFit
                                    horizontalAlignment: Image.AlignLeft
                                    asynchronous: true
                                    sourceSize.width: 1200
                                }

                                Text {
                                    id: contentText
                                    width: parent.width
                                    visible: window.selected !== null && window.selected.type === "text"
                                    text: window.selected === null ? ""
                                        : (window.selectedHidden
                                            ? "Hidden: this looks like a credential." + (SettingsService.clipboardSensitiveExpiry > 0
                                                ? " It is removed from the history " + SettingsService.clipboardSensitiveExpiry + " s after it was copied." : "")
                                            : window.selected.text)
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontPx(12)
                                    font.italic: window.selectedHidden
                                    color: window.selectedHidden ? Theme.textTertiary : Theme.textPrimary
                                    wrapMode: Text.WrapAnywhere
                                    lineHeight: 1.2
                                }

                                Text {
                                    width: parent.width
                                    visible: window.selected !== null && window.selected.type === "files"
                                    text: window.selected === null || window.selected.type !== "files" ? "" : window.selected.files.map(f => History.fileName(f)).join("\n")
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontPx(12)
                                    color: Theme.textPrimary
                                    wrapMode: Text.WrapAnywhere
                                    lineHeight: 1.2
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            color: Theme.overlay(0.08)
                        }

                        // Metadata
                        GridLayout {
                            Layout.fillWidth: true
                            columns: 2
                            columnSpacing: Theme.px(12)
                            rowSpacing: Theme.px(3)

                            Repeater {
                                model: window.selected === null ? [] : window.metadata(window.selected)

                                delegate: RowLayout {
                                    id: metaRow
                                    required property var modelData
                                    Layout.columnSpan: 2
                                    Layout.fillWidth: true
                                    spacing: Theme.px(12)

                                    Text {
                                        Layout.preferredWidth: Theme.px(64)
                                        text: metaRow.modelData[0]
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontPx(11)
                                        color: Theme.textTertiary
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: metaRow.modelData[1]
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontPx(11)
                                        color: Theme.textSecondary
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }

                        // Source app is a guess, so say so
                        RowLayout {
                            Layout.fillWidth: true
                            visible: window.selected !== null && window.selected.type !== "files"
                            spacing: Theme.px(6)

                            Text {
                                text: "⚠"
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontPx(11)
                                color: Theme.accentYellowStrong
                            }

                            Text {
                                Layout.fillWidth: true
                                text: "Source is a best guess: Wayland does not say which app copied, so this is the window that had focus at the time."
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontPx(10)
                                color: Theme.accentYellowStrong
                                wrapMode: Text.WordWrap
                            }
                        }

                        // Actions
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.px(6)

                            ActionButton {
                                text: "Copy"
                                iconName: "copy"
                                onClicked: window.copySelected()
                            }

                            ActionButton {
                                text: window.selected && window.selected.pinned ? "Unpin" : "Pin"
                                iconName: "pin"
                                onClicked: window.togglePinSelected()
                            }

                            ActionButton {
                                visible: window.selected !== null && window.selected.sensitive
                                text: window.selectedHidden ? "Reveal" : "Hide"
                                onClicked: window.toggleReveal()
                            }

                            ActionButton {
                                visible: window.selected !== null && window.selected.kind === "url"
                                text: "Open"
                                onClicked: Quickshell.execDetached(["xdg-open", window.selected.text.trim()])
                            }

                            ActionButton {
                                visible: window.selected !== null && window.selected.type === "files"
                                text: "Open folder"
                                onClicked: Quickshell.execDetached(["xdg-open", window.selected.dir])
                            }

                            Item { Layout.fillWidth: true }

                            ActionButton {
                                text: "Delete"
                                iconName: "trash"
                                danger: true
                                onClicked: window.removeSelected()
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: window.selected === null
                        text: "Select an item to see its details"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontPx(12)
                        color: Theme.textTertiary
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: "↑↓ select  ·  Enter copy  ·  Tab filter  ·  Ctrl+P pin  ·  Ctrl+R reveal  ·  Ctrl+Del delete  ·  Esc close"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontPx(10)
                color: Theme.textTertiary
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
