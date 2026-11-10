import ".."
import QtQuick
import Quickshell
import Quickshell.Wayland
import "dialLogic.js" as Logic

// Experimental category dial launcher: a disc that grows out of the clock pill, with
// categories on an inner ring and apps on an outer arc. Toggled with
// `qs ipc call dial toggle`. Created once per screen; DialService.open opens it on all of them.
PanelWindow {
    id: window

    required property var modelData
    screen: modelData

    color: "transparent"
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    // Stays up while the launched app's icon flies to the pill
    visible: mapped || DialService.launching !== null

    // Unmapped once the disc has shrunk away, like SpotlightWindow
    property bool mapped: false
    Connections {
        target: DialService
        function onOpenChanged() {
            if (DialService.open) {
                unmapTimer.stop();
                window.mapped = true;
                input.forceActiveFocus();
            } else {
                unmapTimer.restart();
            }
        }
    }
    Timer {
        id: unmapTimer
        interval: 420
        onTriggered: window.mapped = false
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-dial"
    WlrLayershell.keyboardFocus: DialService.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Only the disc takes clicks; the rest of the window passes them to the windows below
    mask: Region {
        // Empty while closed, so the launch animation takes no clicks
        x: window.cx - Theme.px(Logic.DISC_RADIUS)
        y: window.cy - Theme.px(Logic.DISC_RADIUS)
        width: DialService.open ? Theme.px(Logic.DISC_RADIUS * 2) : 0
        height: DialService.open ? Theme.px(Logic.DISC_RADIUS * 2) : 0
        shape: RegionShape.Ellipse
    }

    // Centre of the clock pill, where every arc is centred
    readonly property real cx: width / 2
    // The pill is a bar while a window is maximized, hangs flush from the edge in notch
    // style, and floats below it otherwise (see IslandWindow.pillTopY)
    readonly property bool pillIsBar: WindowService.isMaximized && Theme.morphToTopBarWhenMaximized && !WindowService.hasFullscreenApp
    readonly property real pillTop: pillIsBar ? 0 : (Theme.notchStyle ? -1 : Theme.topMargin)
    readonly property real pillHeight: pillIsBar ? Theme.topBarHeight : Theme.compactHeight
    readonly property real cy: pillTop + pillHeight / 2

    readonly property var items: DialService.items
    readonly property int focusIndex: DialService.focusIndex
    // The ring's selection: a category, or a scope while searching
    readonly property int ringIndex: DialService.ringIndex

    // Where the tile at `index` sits in window coordinates, for the launch animation
    function tileCenter(index) {
        let p = Logic.point(Theme.px(Logic.ARC_RADIUS), 90 - (index - window.focusIndex) * Logic.ARC_STEP);
        return { "x": window.cx + p.x, "y": window.cy + p.y };
    }

    // The line under the search field
    readonly property string metaText: {
        let n = window.items.length;
        if (DialService.searching) {
            if (n > 0) return window.items[window.focusIndex].detail;
            return FileSearchService.searching ? "Searching…" : "No matches";
        }
        if (n === 0) {
            if (window.ringIndex === 0) return "No pinned apps";
            return window.ringIndex <= 3 ? "Nothing launched yet" : "No apps";
        }
        return DialService.ringLabels[window.ringIndex] + " · " + n + (n === 1 ? " app" : " apps");
    }

    function launchAt(index) {
        let c = tileCenter(index);
        DialService.launch(window.items[index], c.x, c.y);
    }

    Item {
        id: hit
        x: window.cx - Theme.px(Logic.DISC_RADIUS)
        y: 0
        width: Theme.px(Logic.DISC_RADIUS * 2)
        height: window.cy + Theme.px(Logic.DISC_RADIUS)
        enabled: DialService.open
    }

    WindowBlur {
        target: window
        active: Theme.dockGlass && Theme.blurAvailable
        items: [disc]
    }

    // Everything scales out of the pill centre
    Item {
        id: stage
        anchors.fill: parent
        opacity: DialService.open ? 1 : 0
        // Scale about the pill centre. Item.scale can't be used: with anchors.fill the
        // item's origin is its corner, and the corner is where the growth would start.
        property real grow: DialService.open ? 1 : 0.2
        transform: Scale {
            origin.x: window.cx
            origin.y: window.cy
            xScale: stage.grow
            yScale: stage.grow
        }

        Behavior on opacity { NumberAnimation { duration: 180 } }
        Behavior on grow {
            NumberAnimation {
                duration: 360
                easing.type: Easing.OutBack
                easing.overshoot: 1.15
            }
        }

        Rectangle {
            id: disc
            width: Theme.px(Logic.DISC_RADIUS * 2)
            height: width
            x: window.cx - width / 2
            y: window.cy - height / 2
            radius: width / 2
            color: Theme.dockGlass ? Theme.glassFill : Theme.islandBackground
            border.width: 1
            border.color: Theme.glassHairline
        }

        // Arc scrollbar, shown only when the arc has more items than fit
        Canvas {
            id: bar
            anchors.fill: parent
            opacity: window.items.length > Logic.BAR_MIN_ITEMS ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 180 } }

            readonly property var span: Logic.thumbSpan(window.focusIndex, window.items.length)
            onSpanChanged: requestPaint()
            onWidthChanged: requestPaint()

            onPaint: {
                let ctx = getContext("2d");
                ctx.reset();
                ctx.lineWidth = Theme.px(3);
                ctx.lineCap = "round";
                let r = Theme.px(Logic.BAR_RADIUS);
                function arc(from, to, color) {
                    ctx.strokeStyle = color;
                    ctx.beginPath();
                    ctx.arc(window.cx, window.cy, r, to * Math.PI / 180, from * Math.PI / 180, false);
                    ctx.stroke();
                }
                arc(150, 30, Theme.overlay(0.12));
                arc(span.from, span.to, Theme.textPrimary);
            }
        }

        // Category ring
        Item {
            x: window.cx
            y: window.cy
            rotation: window.ringIndex * Logic.RING_STEP
            Behavior on rotation { enabled: DialService.turning; NumberAnimation { duration: 360; easing.type: Easing.OutBack; easing.overshoot: 1.3 } }

            Repeater {
                model: DialService.ringLabels

                delegate: Rectangle {
                    id: pill
                    required property var modelData
                    required property int index
                    readonly property int distance: Math.abs(index - window.ringIndex)
                    readonly property bool selected: distance === 0
                    readonly property var p: Logic.point(Theme.px(Logic.RING_RADIUS), 90 - index * Logic.RING_STEP)

                    x: p.x - width / 2
                    y: p.y - height / 2
                    rotation: -index * Logic.RING_STEP
                    width: label.implicitWidth + Theme.px(22)
                    height: Theme.px(26)
                    radius: height / 2
                    color: selected ? Theme.accentBlue : Theme.overlay(0.12)
                    opacity: Logic.ringOpacity(distance)
                    enabled: distance <= 3
                    Behavior on opacity { NumberAnimation { duration: 180 } }
                    Behavior on color { ColorAnimation { duration: 180 } }

                    Text {
                        id: label
                        anchors.centerIn: parent
                        text: pill.modelData
                        color: "#ffffff"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontPx(11)
                        font.bold: pill.selected
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: DialService.setRing(pill.index)
                    }
                }
            }
        }

        // App arc
        Item {
            x: window.cx
            y: window.cy
            rotation: window.focusIndex * Logic.ARC_STEP
            Behavior on rotation { enabled: DialService.turning; NumberAnimation { duration: 360; easing.type: Easing.OutBack; easing.overshoot: 1.3 } }

            Repeater {
                model: window.items.length

                delegate: Item {
                    id: slot
                    required property int index
                    readonly property var app: window.items[index]
                    readonly property int distance: Math.abs(index - window.focusIndex)
                    readonly property bool selected: distance === 0
                    readonly property var p: Logic.point(Theme.px(Logic.ARC_RADIUS), 90 - index * Logic.ARC_STEP)

                    // Above its neighbours, whose tiles overlap the pin button and took its clicks
                    z: selected ? 1 : 0

                    // Tiles only exist near the bottom slot; the All category can hold every app
                    Loader {
                        active: slot.distance <= Logic.VISIBLE_APPS + 2
                        x: slot.p.x - Theme.px(42)
                        y: slot.p.y - Theme.px(42)
                        // Kept upright: undo the arc's turn and the slot's own angle
                        rotation: -window.focusIndex * Logic.ARC_STEP
                        opacity: slot.distance <= Logic.VISIBLE_APPS ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 180 } }

                        sourceComponent: Rectangle {
                            width: Theme.px(84)
                            height: Theme.px(84)
                            radius: Theme.px(14)
                            color: slot.selected ? Qt.alpha(Theme.accentBlue, 0.24) : "transparent"
                            border.width: 1
                            border.color: slot.selected ? Qt.alpha(Theme.accentBlue, 0.6) : "transparent"

                            Column {
                                anchors.centerIn: parent
                                spacing: Theme.px(4)

                                Image {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: Theme.px(40)
                                    height: width
                                    sourceSize: Qt.size(width, height)
                                    source: Quickshell.iconPath(slot.app.icon, slot.app.fallback)
                                }
                                Text {
                                    width: Theme.px(76)
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                    text: slot.app.name
                                    color: Theme.textPrimary
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontPx(10)
                                    font.bold: slot.selected
                                }
                                Text {
                                    width: Theme.px(76)
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                    visible: DialService.searching
                                    text: slot.app.sub
                                    color: slot.selected ? Theme.textPrimary : Theme.textSecondary
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontPx(9)
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: slot.distance <= Logic.VISIBLE_APPS
                                onClicked: window.launchAt(slot.index)
                            }

                            // Pin button, the only pin indicator: a dot already means "running"
                            Rectangle {
                                id: pinButton
                                readonly property bool pinned: DialService.isPinned(slot.app)
                                x: Theme.px(67)
                                y: -Theme.px(7)
                                width: Theme.px(24)
                                height: width
                                radius: width / 2
                                color: pinned ? Theme.accentBlue : Theme.switchTrackOff
                                border.width: Theme.px(2)
                                border.color: Theme.islandBackground
                                visible: slot.selected && slot.app.kind === "app"
                                Behavior on color { ColorAnimation { duration: 180 } }

                                SvgIcon {
                                    anchors.centerIn: parent
                                    name: "pin"
                                    size: Theme.px(12)
                                    color: "#ffffff"
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -Theme.px(4)
                                    onClicked: DialService.togglePin(slot.app)
                                }
                            }
                        }
                    }
                }
            }
        }

        // Search field, with what the selected hit is, or the category, on the line below
        Column {
            x: window.cx - width / 2
            y: window.cy + Theme.px(31)
            width: Theme.px(400)
            spacing: Theme.px(4)

            TextInput {
                id: input
                width: parent.width
                horizontalAlignment: TextInput.AlignHCenter
                color: Theme.textPrimary
                selectionColor: Theme.accentBlue
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontPx(20)
                font.bold: true
                clip: true
                focus: true
                onTextEdited: DialService.setQuery(text)

                Connections {
                    target: DialService
                    function onQueryChanged() {
                        if (input.text !== DialService.query) input.text = DialService.query;
                    }
                }

                Text {
                    anchors.fill: parent
                    horizontalAlignment: Text.AlignHCenter
                    visible: input.text === ""
                    text: "Search apps, settings, files…"
                    color: Theme.textSecondary
                    font: input.font
                }

                Keys.onPressed: event => {
                    if (!DialService.open) return;
                    switch (event.key) {
                    case Qt.Key_Right: DialService.setFocus(window.focusIndex + 1); break;
                    case Qt.Key_Left: DialService.setFocus(window.focusIndex - 1); break;
                    case Qt.Key_Down: DialService.setRing(window.ringIndex + 1); break;
                    case Qt.Key_Up: DialService.setRing(window.ringIndex - 1); break;
                    case Qt.Key_Return:
                    case Qt.Key_Enter:
                        if (window.items.length > 0) window.launchAt(window.focusIndex);
                        break;
                    case Qt.Key_P:
                        if (!(event.modifiers & Qt.ControlModifier)) return;
                        DialService.togglePin(window.items[window.focusIndex]);
                        break;
                    case Qt.Key_Escape:
                        // Clears the search first, then closes
                        if (DialService.searching) DialService.setQuery("");
                        else DialService.close();
                        break;
                    default: return;
                    }
                    event.accepted = true;
                }
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: window.metaText
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontPx(11)
            }
        }
    }

    // The pill while an app opens: widens and names the app, drawn over the island's own pill
    Rectangle {
        id: openingPill
        readonly property bool flying: DialService.launching !== null && DialService.launching.phase >= 1
        width: flying ? Theme.px(260) : Theme.compactWidthClock
        height: window.pillHeight
        x: window.cx - width / 2
        y: window.pillTop
        radius: window.pillIsBar ? 0 : Theme.compactRadius
        // Flat top in notch style
        topLeftRadius: window.pillIsBar || Theme.notchStyle ? 0 : Theme.compactRadius
        topRightRadius: topLeftRadius
        bottomLeftRadius: window.pillIsBar ? 0 : (Theme.notchStyle ? Theme.notchRadius : Theme.compactRadius)
        bottomRightRadius: bottomLeftRadius
        color: Theme.islandSurface
        opacity: DialService.launching !== null && DialService.launching.phase === 1 ? 1 : 0
        Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 180 } }

        Text {
            anchors.centerIn: parent
            width: parent.width - Theme.px(80)
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: DialService.launching ? "Opening " + DialService.launching.name : ""
            color: Theme.textPrimary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontPx(12)
            font.bold: true
        }
    }

    // The launched app's icon, flying from its tile into the pill
    Image {
        id: flyIcon
        readonly property var launch: DialService.launching
        readonly property bool flying: launch !== null && launch.phase >= 1
        width: Theme.px(40)
        height: width
        sourceSize: Qt.size(width, height)
        source: launch ? Quickshell.iconPath(launch.icon, launch.fallback) : ""
        // Parked at the tile until phase 1, then moves to the left end of the pill
        x: (flying ? window.cx - Theme.px(130) + Theme.px(20) : (launch ? launch.x : window.cx)) - width / 2
        y: (flying ? window.cy : (launch ? launch.y : window.cy)) - height / 2
        scale: flying ? 0.45 : 1
        opacity: launch && launch.phase < 2 ? 1 : 0
        Behavior on opacity { enabled: flyIcon.launch !== null && flyIcon.launch.phase === 2; NumberAnimation { duration: 150 } }
        Behavior on x { enabled: flyIcon.flying; NumberAnimation { duration: 420; easing.type: Easing.InOutCubic } }
        Behavior on y { enabled: flyIcon.flying; NumberAnimation { duration: 420; easing.type: Easing.InOutCubic } }
        Behavior on scale { enabled: flyIcon.flying; NumberAnimation { duration: 420; easing.type: Easing.InOutCubic } }
    }

    // Clicking the pill in the middle of the disc closes it, as clicking the pill opened it
    MouseArea {
        x: window.cx - Theme.compactWidthClock / 2
        y: window.pillTop
        width: Theme.compactWidthClock
        height: window.pillHeight
        enabled: DialService.open
        cursorShape: Qt.PointingHandCursor
        onClicked: DialService.close()
    }

    // Wheel inside the turn radius turns the ring, outside it the arc
    MouseArea {
        anchors.fill: hit
        enabled: DialService.open
        acceptedButtons: Qt.NoButton
        property real lastStep: 0
        onWheel: wheel => {
            let now = Date.now();
            if (now - lastStep < 140) return;
            lastStep = now;
            let dx = wheel.x + hit.x - window.cx;
            let dy = wheel.y + hit.y - window.cy;
            let dir = Logic.wheelDirection(wheel.angleDelta.y === 0 ? 0 : -wheel.angleDelta.y, -wheel.angleDelta.x);
            if (Math.sqrt(dx * dx + dy * dy) < Theme.px(Logic.TURN_RADIUS)) DialService.setRing(window.ringIndex + dir);
            else DialService.setFocus(window.focusIndex + dir);
        }
    }
}
