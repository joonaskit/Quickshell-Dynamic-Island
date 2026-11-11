import ".."
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import "dialLogic.js" as Logic

// Experimental category dial launcher: a disc that slides down around the clock pill, with
// categories on an inner ring and apps on an outer arc. Toggled with
// `qs ipc call dial toggle`. Created once per screen; it shows on DialService.screenName only.
PanelWindow {
    id: window

    required property var modelData
    screen: modelData

    // This is the screen the dial opened on, and it is open
    readonly property bool here: !window.screen || DialService.screenName === "" || DialService.screenName === window.screen.name
    readonly property bool shown: DialService.open && here

    color: "transparent"
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    // Stays up while the launched app's icon flies to the pill
    visible: mapped || (DialService.launching !== null && here)

    // Unmapped once the disc has shrunk away, like SpotlightWindow
    property bool mapped: false
    onShownChanged: {
        menu.entries = [];
        if (shown) {
            unmapTimer.stop();
            mapped = true;
            input.forceActiveFocus();
        } else {
            unmapTimer.restart();
        }
    }
    Timer {
        id: unmapTimer
        interval: 420
        onTriggered: window.mapped = false
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-dial"
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // While open the whole screen takes clicks, so one outside the disc closes it. Empty
    // while closed, so the launch animation takes no clicks.
    mask: Region {
        width: window.shown ? window.width : 0
        height: window.shown ? window.height : 0
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

    // How far a ring is turned, in steps. It glides to `index` when the selection moves,
    // further and faster the further away that is, and follows the pointer while grabbed.
    component Spinner: Item {
        id: spinner

        property int index: 0
        property int count: 0
        property real position: 0
        property bool grabbed: false
        // The slot at the bottom right now, which is not `index` until the ring has settled
        readonly property int nearest: Math.round(position)

        // The slot the user turned the ring to, by dragging or flicking it
        signal turned(int slot)

        function settle() {
            let distance = Math.abs(index - position);
            glide.stop();
            // Hits landing under a typed search just land (see DialService.turning)
            if (!DialService.turning || distance === 0) {
                position = index;
                return;
            }
            glide.from = position;
            glide.to = index;
            glide.duration = Logic.turnDuration(distance);
            glide.easing.overshoot = Logic.turnOvershoot(distance);
            glide.start();
        }

        function grab() {
            glide.stop();
            grabbed = true;
        }

        function drag(steps) {
            position = Logic.dragTurn(position + steps, count);
            if (nearest !== index) turned(nearest);
        }

        // Let go at `velocity` steps a second: the ring carries on to the slot that takes it to
        function release(velocity) {
            grabbed = false;
            turned(Logic.flickTarget(position, velocity, count));
            settle();
        }

        onIndexChanged: if (!grabbed) settle()
        Component.onCompleted: position = index

        NumberAnimation {
            id: glide
            target: spinner
            property: "position"
            easing.type: Easing.OutBack
        }
    }

    // Category pills are spaced by width. Widths are of the bold label, so a pill keeps
    // its size, and the ring its spacing, when the selection moves.
    FontMetrics {
        id: pillMetrics
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontPx(11)
        font.bold: true
    }
    readonly property var ringWidths: DialService.ringLabels.map(text => pillMetrics.advanceWidth(text) + Theme.px(22))
    // Degrees from the first pill to each one
    readonly property var ringAngles: Logic.ringAngles(ringWidths, Theme.px(Logic.RING_RADIUS), Theme.px(Logic.RING_GAP))

    Spinner {
        id: ringSpin
        index: window.ringIndex
        count: DialService.ringLabels.length
        onTurned: slot => DialService.setRing(slot)
    }

    Spinner {
        id: arcSpin
        index: window.focusIndex
        count: window.items.length
        onTurned: slot => DialService.setFocus(slot)
    }

    // Where the tile at `index` sits in window coordinates, for the launch animation
    function tileCenter(index) {
        let p = Logic.point(Theme.px(Logic.ARC_RADIUS), 90 - (index - arcSpin.position) * Logic.ARC_STEP);
        return { "x": window.cx + p.x, "y": window.cy + p.y };
    }

    // The line under the search field
    readonly property string metaText: {
        let n = window.items.length;
        if (DialService.searching) {
            if (n > 0) return window.items[window.focusIndex].detail;
            return FileSearchService.searching ? "Searching…" : "No matches";
        }
        let kind = DialService.categoryKind;
        if (n === 0) {
            if (kind === "pinned") return "No pinned apps";
            if (kind === "windows") return "No open windows";
            return kind === "recent" || kind === "frequent" ? "Nothing launched yet" : "No apps";
        }
        // A window's line says which app it is and its full title
        if (kind === "windows") return window.items[window.focusIndex].detail;
        return DialService.ringLabels[window.ringIndex] + " · " + n + (n === 1 ? " app" : " apps");
    }

    function launchAt(index) {
        let c = tileCenter(index);
        DialService.launch(window.items[index], c.x, c.y);
    }

    // Opens the right-click menu of the tile at `index`, with its corner at x, y (window
    // coordinates) and kept on the screen
    function openMenu(index, x, y) {
        let item = window.items[index];
        if (!item) return;
        DialService.setFocus(index);
        let c = tileCenter(index);
        menu.entries = DialService.menuFor(item, c.x, c.y);
        menu.current = -1;
        menu.x = Math.max(0, Math.min(x, window.width - menu.width));
        menu.y = Math.max(0, Math.min(y, window.height - menu.height));
    }

    // The focused tile's menu from the keyboard, beside the tile with its first entry lit
    function openFocusedMenu() {
        let c = tileCenter(focusIndex);
        openMenu(focusIndex, c.x + Theme.px(42), c.y - Theme.px(42));
        if (menu.isOpen) menu.move(1);
    }

    function runMenuEntry(entry) {
        menu.entries = [];
        if (!entry || entry.separator) return;
        entry.run();
        if (entry.closes) DialService.close();
    }

    // A press outside the disc closes the dial. Below everything else, so the disc's own
    // tiles, pills and field take their presses first.
    MouseArea {
        anchors.fill: parent
        enabled: window.shown
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onPressed: mouse => {
            if (menu.isOpen) menu.entries = [];
            else if (Math.hypot(mouse.x - window.cx, mouse.y - window.cy) > Theme.px(Logic.DISC_RADIUS)) DialService.close();
        }
    }

    Item {
        id: hit
        x: window.cx - Theme.px(Logic.DISC_RADIUS)
        y: 0
        width: Theme.px(Logic.DISC_RADIUS * 2)
        height: window.cy + Theme.px(Logic.DISC_RADIUS)
        enabled: window.shown
    }

    WindowBlur {
        target: window
        active: Theme.dockGlass && Theme.blurAvailable
        items: [disc]
    }

    // Everything slides down from behind the top edge of the screen
    Item {
        id: stage
        width: parent.width
        height: parent.height
        // Closed, the whole disc is above the screen. Moved by y, not a transform: WindowBlur
        // places the blur on the same frame for a move, and a frame late for a transform,
        // which let the desktop show sharp through the disc's leading edge.
        y: window.shown ? 0 : -(window.cy + Theme.px(Logic.DISC_RADIUS))
        opacity: window.shown ? 1 : 0

        Behavior on opacity { NumberAnimation { duration: 180 } }
        Behavior on y { NumberAnimation { duration: 360; easing.type: Easing.OutCubic } }

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

        // Thin border between the category ring and the app arc, always visible. The
        // scrollbar below sits on it.
        Rectangle {
            width: Theme.px(Logic.BAR_RADIUS * 2)
            height: width
            x: window.cx - width / 2
            y: window.cy - height / 2
            radius: width / 2
            color: "transparent"
            border.width: 1
            border.color: Theme.glassHairline
        }

        // Arc scrollbar, shown only when the arc has more items than fit. The thumb moves
        // with the arc as it turns.
        Shape {
            id: bar
            x: window.cx
            y: window.cy
            preferredRendererType: Shape.CurveRenderer
            opacity: window.items.length > Logic.BAR_MIN_ITEMS ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 180 } }

            readonly property real radius: Theme.px(Logic.BAR_RADIUS)
            readonly property var span: Logic.thumbSpan(arcSpin.position, window.items.length)

            ShapePath {
                fillColor: "transparent"
                strokeColor: Theme.overlay(0.12)
                strokeWidth: Theme.px(3)
                capStyle: ShapePath.RoundCap
                PathAngleArc { radiusX: bar.radius; radiusY: bar.radius; startAngle: 30; sweepAngle: 120 }
            }
            ShapePath {
                fillColor: "transparent"
                strokeColor: Theme.textPrimary
                strokeWidth: Theme.px(3)
                capStyle: ShapePath.RoundCap
                PathAngleArc { radiusX: bar.radius; radiusY: bar.radius; startAngle: bar.span.to; sweepAngle: bar.span.from - bar.span.to }
            }
        }

        // Category ring. Each pill is bent along the ring, and so is its label.
        Item {
            x: window.cx
            y: window.cy
            rotation: Logic.ringAngleAt(window.ringAngles, ringSpin.position)

            Repeater {
                model: DialService.ringLabels

                delegate: Item {
                    id: pill
                    required property string modelData
                    required property int index
                    readonly property bool selected: index === window.ringIndex
                    readonly property real radius: Theme.px(Logic.RING_RADIUS)
                    readonly property real half: Theme.px(13)
                    // Where on the ring it sits, and the angles its two round ends are centred on
                    // The model can be a step ahead of the widths when the labels change
                    readonly property real length: window.ringWidths[index] || half * 2
                    readonly property real angle: 90 - (window.ringAngles[index] || 0)
                    readonly property real sweep: Math.max(0, length - half * 2) / radius * 180 / Math.PI
                    readonly property real from: angle - sweep / 2
                    readonly property real to: angle + sweep / 2
                    readonly property var fromEnd: Logic.point(radius, from)
                    readonly property var toEnd: Logic.point(radius, to)

                    opacity: Logic.ringOpacity(Math.abs(index - ringSpin.position))
                    enabled: Math.abs(index - ringSpin.nearest) <= 3

                    TextMetrics {
                        id: label
                        text: pill.modelData
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontPx(11)
                        font.bold: pill.selected
                    }

                    // Outer edge, round end, inner edge and round end again
                    Shape {
                        preferredRendererType: Shape.CurveRenderer

                        ShapePath {
                            fillColor: pill.selected ? Theme.accentBlue : Theme.overlay(pillHover.hovered ? 0.2 : 0.12)
                            strokeColor: "transparent"
                            Behavior on fillColor { ColorAnimation { duration: 180 } }

                            PathAngleArc {
                                radiusX: pill.radius + pill.half
                                radiusY: radiusX
                                startAngle: pill.from
                                sweepAngle: pill.sweep
                            }
                            PathAngleArc {
                                moveToStart: false
                                centerX: pill.toEnd.x
                                centerY: pill.toEnd.y
                                radiusX: pill.half
                                radiusY: pill.half
                                startAngle: pill.to
                                sweepAngle: 180
                            }
                            PathAngleArc {
                                moveToStart: false
                                radiusX: pill.radius - pill.half
                                radiusY: radiusX
                                startAngle: pill.to
                                sweepAngle: -pill.sweep
                            }
                            PathAngleArc {
                                moveToStart: false
                                centerX: pill.fromEnd.x
                                centerY: pill.fromEnd.y
                                radiusX: pill.half
                                radiusY: pill.half
                                startAngle: pill.from + 180
                                sweepAngle: 180
                            }
                        }
                    }

                    // One letter at a time, each turned to the ring where it stands
                    Repeater {
                        model: pill.modelData.length

                        delegate: Text {
                            id: letter
                            required property int index
                            // Px from the middle of the label to the middle of this letter. The
                            // label reads left to right, which is against the angle.
                            readonly property real along: before.advanceWidth + implicitWidth / 2 - label.advanceWidth / 2
                            readonly property real angle: pill.angle - along / pill.radius * 180 / Math.PI
                            readonly property var p: Logic.point(pill.radius, angle)

                            x: p.x - width / 2
                            y: p.y - height / 2
                            rotation: angle - 90
                            text: pill.modelData[index]
                            color: "#ffffff"
                            font: label.font

                            TextMetrics {
                                id: before
                                font: label.font
                                text: pill.modelData.substring(0, letter.index)
                            }
                        }
                    }

                    // A straight box over the bent pill, close enough for clicks
                    Item {
                        readonly property var p: Logic.point(pill.radius, pill.angle)
                        x: p.x - width / 2
                        y: p.y - height / 2
                        width: pill.length
                        height: pill.half * 2
                        rotation: pill.angle - 90

                        HoverHandler { id: pillHover }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: DialService.setRing(pill.index)
                        }
                    }
                }
            }
        }

        // App arc
        Item {
            id: arc
            x: window.cx
            y: window.cy
            rotation: arcSpin.position * Logic.ARC_STEP

            Repeater {
                model: window.items.length

                delegate: Item {
                    id: slot
                    required property int index
                    readonly property var app: window.items[index]
                    // Steps from the bottom slot as the arc stands now, mid-turn too
                    readonly property int distance: Math.abs(index - arcSpin.nearest)
                    readonly property bool selected: index === window.focusIndex
                    readonly property var p: Logic.point(Theme.px(Logic.ARC_RADIUS), 90 - index * Logic.ARC_STEP)

                    // Above its neighbours, whose tiles overlap the pin button and took its clicks
                    z: selected ? 1 : 0

                    // Tiles only exist near the bottom slot; the All category can hold every app
                    Loader {
                        active: slot.distance <= Logic.VISIBLE_APPS + 2
                        x: slot.p.x - Theme.px(42)
                        y: slot.p.y - Theme.px(42)
                        // Kept upright all through a turn: undo the arc's rotation as it is now
                        rotation: -arc.rotation
                        // Fades with its place on the arc. Only tiles that exist follow the turn.
                        opacity: active ? Logic.arcOpacity(Math.abs(slot.index - arcSpin.position)) : 0

                        sourceComponent: Rectangle {
                            width: Theme.px(84)
                            height: Theme.px(84)
                            radius: Theme.px(14)
                            color: slot.selected ? Qt.alpha(Theme.accentBlue, 0.24) : Theme.overlay(tileHover.hovered ? 0.08 : 0)
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 120 } }

                            HoverHandler { id: tileHover }
                            border.color: slot.selected ? Qt.alpha(Theme.accentBlue, 0.6) : "transparent"

                            Column {
                                anchors.centerIn: parent
                                // Up a little, to leave the running dot room
                                anchors.verticalCenterOffset: -Theme.px(3)
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
                                    visible: DialService.searching || slot.app.kind === "window"
                                    text: slot.app.sub
                                    color: slot.selected ? Theme.textPrimary : Theme.textSecondary
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontPx(9)
                                }
                            }

                            // Running indicator, as on the dock
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: Theme.px(3)
                                width: Theme.px(5)
                                height: width
                                radius: width / 2
                                color: slot.selected ? Theme.accentBlue : Theme.textSecondary
                                visible: DialService.isRunning(slot.app)
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: slot.distance <= Logic.VISIBLE_APPS
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: mouse => {
                                    if (mouse.button === Qt.RightButton) {
                                        let p = mapToItem(null, mouse.x, mouse.y);
                                        window.openMenu(slot.index, p.x, p.y);
                                    } else {
                                        window.launchAt(slot.index);
                                    }
                                }
                            }

                            // Pin button, the only pin indicator: the dot below means "running"
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
            // The text sits where the prototype has it; the box takes 4 px above it
            y: window.cy + Theme.px(27)
            width: Theme.px(400)
            spacing: Theme.px(4)

            // Border round the field, narrower than the line below so it clears the ring
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Theme.px(320)
                height: input.height + Theme.px(8)
                radius: height / 2
                color: "transparent"
                border.width: 1
                border.color: Theme.glassHairline

                TextInput {
                    id: input
                    anchors.centerIn: parent
                    width: parent.width - Theme.px(32)
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
                        text: "Search"
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: input.font.pixelSize
                        font.weight: Font.Light
                    }

                    Keys.onPressed: event => {
                        if (!window.shown) return;
                        // While the menu is open the keys move through it
                        if (menu.isOpen) {
                            switch (event.key) {
                            case Qt.Key_Down: menu.move(1); break;
                            case Qt.Key_Up: menu.move(-1); break;
                            case Qt.Key_Return:
                            case Qt.Key_Enter: menu.choose(); break;
                            case Qt.Key_Escape:
                            case Qt.Key_Menu: menu.entries = []; break;
                            default: return;
                            }
                            event.accepted = true;
                            return;
                        }
                        let jump = { [Qt.Key_Home]: "home", [Qt.Key_End]: "end", [Qt.Key_PageUp]: "pageUp", [Qt.Key_PageDown]: "pageDown" }[event.key];
                        if (jump) {
                            DialService.setFocus(Logic.jumpTarget(jump, window.focusIndex, window.items.length));
                            event.accepted = true;
                            return;
                        }
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
                        // The menu of the focused tile, opened beside it
                        case Qt.Key_F10:
                            if (!(event.modifiers & Qt.ShiftModifier)) return;
                            window.openFocusedMenu();
                            break;
                        case Qt.Key_Menu:
                            window.openFocusedMenu();
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

    // The Spinner whose ring is under a point of `hit`: the category ring inside the turn
    // radius, the app arc outside it
    function spinnerAt(x, y) {
        return Math.hypot(x + hit.x - window.cx, y + hit.y - window.cy) < Theme.px(Logic.TURN_RADIUS) ? ringSpin : arcSpin;
    }

    // Wheel turns the ring or the arc, whichever the pointer is over
    MouseArea {
        anchors.fill: hit
        enabled: window.shown
        acceptedButtons: Qt.NoButton

        // Deltas not yet worth a step, and where and when they came in
        property real carry: 0
        property var over: null
        property real time: 0

        onWheel: wheel => {
            if (grip.pressed) return;
            let now = Date.now();
            let spinner = window.spinnerAt(wheel.x, wheel.y);
            if (spinner !== over || now - time > 400) carry = 0;
            over = spinner;
            time = now;
            // Down or right is forward. A touchpad's lift-off event has no delta and turns nothing.
            let delta = wheel.angleDelta.y !== 0 ? -wheel.angleDelta.y : -wheel.angleDelta.x;
            let turn = Logic.wheelSteps(carry, delta);
            carry = turn.carry;
            if (turn.steps === 0) return;
            if (spinner === ringSpin) DialService.setRing(window.ringIndex + turn.steps);
            else DialService.setFocus(window.focusIndex + turn.steps);
        }
    }

    // Grabs the ring or the arc to drag it round; a flick sends it spinning on. Clicks go
    // through to the tile or pill below.
    MouseArea {
        id: grip
        anchors.fill: hit
        enabled: window.shown
        propagateComposedEvents: true
        cursorShape: pressed && dragged ? Qt.ClosedHandCursor : Qt.OpenHandCursor

        // Only the two rings can be grabbed. The search field and the pill in the middle
        // keep their own presses and cursor.
        containmentMask: QtObject {
            function contains(point: point): bool {
                let r = Math.hypot(point.x + hit.x - window.cx, point.y + hit.y - window.cy);
                return r >= Theme.px(Logic.GRAB_RADIUS) && r <= Theme.px(Logic.DISC_RADIUS);
            }
        }

        // The Spinner under the press
        property var turner: null
        property bool dragged: false
        property real pressX: 0
        property real pressY: 0
        property real lastAngle: 0
        // Recent { t, turn } of the drag, for the speed at release
        property var samples: []

        // Steps the grabbed ring turns when the pointer goes `degrees` round the pill.
        // The category ring's steps differ, as its pills are spaced by width.
        function stepsFor(degrees) {
            if (turner === arcSpin) return degrees / Logic.ARC_STEP;
            let at = Logic.ringAngleAt(window.ringAngles, turner.position);
            return Logic.ringPositionAt(window.ringAngles, at + degrees) - turner.position;
        }

        function letGo(velocity) {
            if (turner !== null && dragged) turner.release(velocity);
            turner = null;
        }

        onPressed: mouse => {
            menu.entries = [];
            dragged = false;
            turner = window.spinnerAt(mouse.x, mouse.y);
            pressX = mouse.x;
            pressY = mouse.y;
        }

        onPositionChanged: mouse => {
            if (turner === null) return;
            let angle = Math.atan2(mouse.y + hit.y - window.cy, mouse.x + hit.x - window.cx) * 180 / Math.PI;
            let now = Date.now();
            if (!dragged) {
                if (Math.hypot(mouse.x - pressX, mouse.y - pressY) < Theme.px(Logic.DRAG_START)) return;
                dragged = true;
                turner.grab();
                samples = [];
            } else {
                turner.drag(stepsFor(Logic.angleStep(lastAngle, angle)));
            }
            lastAngle = angle;
            samples = samples.filter(s => now - s.t <= Logic.FLICK_WINDOW).concat([{ "t": now, "turn": turner.position }]);
        }

        onReleased: letGo(Logic.flickVelocity(samples, Date.now()))
        onCanceled: letGo(0)
        // A press that did not drag is a click for the tile or pill under it
        onClicked: mouse => mouse.accepted = dragged
    }

    // Clicking the pill in the middle of the disc closes it, as clicking the pill opened it
    MouseArea {
        x: window.cx - Theme.compactWidthClock / 2
        y: window.pillTop
        width: Theme.compactWidthClock
        height: window.pillHeight
        enabled: window.shown
        cursorShape: Qt.PointingHandCursor
        onClicked: DialService.close()
    }

    // Right-click menu of a tile, over everything else
    DialMenu {
        id: menu
        onChosen: entry => window.runMenuEntry(entry)
    }
}
