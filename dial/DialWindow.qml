import ".."
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.UPower
import "dialLogic.js" as Logic
import "dialPages.js" as Pages
import "../services/clipboardHistory.js" as ClipboardHistory

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

    // The battery, for the power page
    QtObject {
        id: battery
        readonly property var device: UPower.displayDevice
        readonly property bool present: device !== null && device.isPresent
        readonly property real fraction: present ? Math.min(1, Math.max(0, device.percentage <= 1 ? device.percentage : device.percentage / 100)) : 1
        readonly property bool charging: present && device.state === UPowerDeviceState.Charging
        readonly property bool full: present && (device.state === UPowerDeviceState.FullyCharged || fraction >= 0.99)
        readonly property string tone: Logic.batteryTone(fraction, charging)
        readonly property color color: {
            switch (tone) {
            case "charging": return Theme.accentGreenStrong;
            case "critical": return Theme.accentRed;
            case "low": return Theme.accentOrangeStrong;
            }
            return Theme.textPrimary;
        }
        readonly property string status: Logic.batteryStatus(present, charging, full, present ? device.timeToFull : 0, present ? device.timeToEmpty : 0)
    }

    // What the open page shows in the middle and on the gauge. `gauge` is 0 to 1, or -1
    // for none. With `slider` the gauge can be dragged (DialService.setSlider).
    readonly property var connectedNetwork: NetworkService.availableNetworks.find(n => n.inUse) || null
    readonly property var pageView: {
        if (DialService.page === "power") return {
            "gauge": battery.present ? battery.fraction : -1,
            "color": battery.color,
            "title": battery.present ? Math.round(battery.fraction * 100) + "%" : "Plugged in",
            "titleColor": battery.present ? battery.color : Theme.textPrimary,
            "titleSize": battery.present ? 34 : 24,
            "status": battery.status
        };
        if (DialService.page === "wifi") {
            let on = NetworkService.isWifiEnabled;
            let net = window.connectedNetwork;
            return {
                "gauge": on && net ? net.signal / 100 : -1,
                "color": Theme.accentBlue,
                "title": DialService.passwordFor !== "" ? "Join " + DialService.passwordFor
                    : (!on ? "Wi-Fi off" : (net ? net.ssid : "Not connected")),
                "titleColor": on && net ? Theme.textPrimary : Theme.textSecondary,
                "titleSize": 24,
                "status": Logic.wifiStatus(on, net !== null, NetworkService.connectingSsid, NetworkService.isScanning, net ? net.signal : 0, NetworkService.availableNetworks.length, NetworkService.failedSsid)
            };
        }
        if (DialService.page === "hardware") {
            let metric = DialService.hardwareMetric;
            let hw = HardwareStatsService;
            let value = [hw.cpuPercent, hw.ramPercent, hw.cpuTemp][metric];
            let tone = Logic.hardwareTone(metric, value);
            let normal = metric === 2 ? Theme.accentGreenStrong : Theme.accentBlue;
            let color = tone === "critical" ? Theme.accentRed : (tone === "high" ? Theme.accentOrangeStrong : normal);
            return {
                // Temperature fills the gauge up to 100 °C
                "gauge": metric === 2 && value <= 0 ? -1 : Math.min(1, value / 100),
                "color": color,
                "title": Logic.hardwareTitle(metric, hw.cpuPercent, hw.ramPercent, hw.cpuTemp),
                "titleColor": tone === "normal" ? Theme.textPrimary : color,
                "titleSize": 34,
                "status": Logic.hardwareStatus(metric, hw.cpuPercent, hw.ramPercent, hw.ramUsedGb, hw.ramTotalGb, hw.cpuTemp)
            };
        }
        if (DialService.page === "bluetooth") {
            let on = BluetoothService.isEnabled;
            let connected = BluetoothService.connectedDevices;
            // The first connected device that reports its battery fills the gauge
            let powered = connected.find(d => d.battery >= 0);
            let connecting = BluetoothService.pairedDevices.find(d => d.mac === BluetoothService.connectingMac);
            return {
                "gauge": on && powered ? powered.battery : -1,
                "color": Theme.accentBlue,
                "title": !BluetoothService.isAvailable ? "No Bluetooth"
                    : (!on ? "Bluetooth off" : (connected.length > 0 ? connected[0].name : "Not connected")),
                "titleColor": on && connected.length > 0 ? Theme.textPrimary : Theme.textSecondary,
                "titleSize": 24,
                "status": Logic.bluetoothStatus(BluetoothService.isAvailable, on, connected.length > 0, connecting ? connecting.name : "",
                    powered ? powered.battery : -1, BluetoothService.pairedDevices.length)
            };
        }
        if (DialService.page === "mic") {
            let mic = MicrophoneService;
            let present = mic.source !== null;
            return {
                "gauge": present ? mic.volume : -1,
                "slider": present,
                "color": mic.isMuted ? Theme.overlay(0.35) : Theme.accentRed,
                "title": present ? Math.round(mic.volume * 100) + "%" : "No microphone",
                "titleColor": present && !mic.isMuted ? Theme.accentRed : Theme.textSecondary,
                "titleSize": present ? 34 : 24,
                "status": Logic.micStatus(present, mic.isMuted, mic.defaultSource)
            };
        }
        if (DialService.page === "nightLight") {
            let night = NightLightService;
            return {
                "gauge": night.available ? Pages.levelOf(night.nightTemperature, night.minTemperature, night.maxTemperature) : -1,
                "slider": night.available,
                "color": night.switchedOn ? Theme.accentOrangeStrong : Theme.overlay(0.35),
                "title": night.available ? night.nightTemperature + " K" : "Night Light",
                "titleColor": night.running ? Theme.accentOrangeStrong : (night.switchedOn ? Theme.textPrimary : Theme.textSecondary),
                "titleSize": night.available ? 34 : 24,
                "status": Pages.nightLightStatus(night)
            };
        }
        if (DialService.page === "hue") {
            let light = HueService.selectedLight;
            let dims = light !== null && light.hasBrightness;
            return {
                "gauge": dims ? light.brightness / 100 : -1,
                "slider": dims,
                "color": light !== null && light.on ? Theme.accentOrangeStrong : Theme.overlay(0.35),
                "title": Pages.hueTitle(light),
                "titleColor": light !== null && light.on ? Theme.textPrimary : Theme.textSecondary,
                "titleSize": light !== null ? 34 : 24,
                "status": Pages.hueStatus(HueService.error, HueService.connected, light)
            };
        }
        if (DialService.page === "notification") {
            let count = (NotificationService.notifications || []).length;
            return {
                "gauge": -1,
                "color": Theme.accentPurple,
                "title": Pages.notificationTitle(count),
                "titleColor": count > 0 ? Theme.textPrimary : Theme.textSecondary,
                "titleSize": 24,
                "status": Pages.notificationStatus(window.items[window.focusIndex], SettingsService.dndEnabled)
            };
        }
        if (DialService.page === "clipboard") {
            let saved = ClipboardService.history.length;
            return {
                "gauge": -1,
                "color": Theme.accentBlue,
                "title": saved === 0 ? "Clipboard" : saved + (saved === 1 ? " item" : " items"),
                "titleColor": saved > 0 ? Theme.textPrimary : Theme.textSecondary,
                "titleSize": 24,
                "status": Pages.clipboardStatus(ClipboardService, ClipboardHistory.preview(ClipboardService.currentText, 60))
            };
        }
        if (DialService.page === "kdeConnect") {
            let phone = KdeConnectService.device;
            let reachable = phone !== null && phone.reachable;
            return {
                "gauge": reachable && phone.hasBattery ? phone.charge / 100 : -1,
                "color": Theme.accentGreenStrong,
                "title": phone !== null ? phone.name : "KDE Connect",
                "titleColor": reachable ? Theme.textPrimary : Theme.textSecondary,
                "titleSize": 24,
                "status": Pages.kdeStatus(KdeConnectService.daemonAvailable, phone, KdeConnectService.notice)
            };
        }
        if (DialService.page === "usb") {
            return {
                "gauge": -1,
                "color": Theme.accentGreenStrong,
                "title": Pages.driveTitle(DeviceService.deviceCount),
                "titleColor": DeviceService.hasDevices ? Theme.textPrimary : Theme.textSecondary,
                "titleSize": 24,
                "status": Pages.driveStatus(DeviceService.deviceCount, DeviceService.mountedCount, DeviceService.operatingDevice, DeviceService.statusMessage)
            };
        }
        if (DialService.page === "gameMode") {
            let game = GameModeService;
            return {
                "gauge": -1,
                "color": Theme.accentGreenStrong,
                "title": Pages.gameTitle(game.available, game.active),
                "titleColor": game.available && game.active ? Theme.accentGreenStrong : Theme.textSecondary,
                "titleSize": 24,
                "status": Pages.gameStatus(game.available, game.games.length, game.forced)
            };
        }
        return { "gauge": -1, "color": Theme.textPrimary, "title": "", "titleColor": Theme.textPrimary, "titleSize": 24, "status": "" };
    }

    // Opening or leaving a page spins the new tiles and pills in from the side
    Connections {
        target: DialService
        function onPageChanged() {
            Qt.callLater(() => {
                arcSpin.position = arcSpin.index - 3;
                arcSpin.settle();
                ringSpin.position = ringSpin.index - 2;
                ringSpin.settle();
            });
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

    readonly property var pageKeys: [Qt.Key_Left, Qt.Key_Right, Qt.Key_Up, Qt.Key_Down, Qt.Key_Home, Qt.Key_End,
        Qt.Key_PageUp, Qt.Key_PageDown, Qt.Key_Return, Qt.Key_Enter, Qt.Key_Escape]

    function launchAt(index) {
        let c = tileCenter(index);
        // A program or a notification has nothing to launch: choosing it opens its menu
        if (window.items[index] && (window.items[index].kind === "process" || window.items[index].kind === "notification")) {
            openMenu(index, c.x + Theme.px(42), c.y - Theme.px(42));
            if (menu.isOpen) menu.move(1);
            return;
        }
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

        // A page's gauge on the border circle, filling from the left: the battery level, the
        // Wi-Fi signal, or the microphone's input level, which can be dragged
        Shape {
            id: gauge
            x: window.cx
            y: window.cy
            preferredRendererType: Shape.CurveRenderer
            opacity: DialService.page !== "" && window.pageView.gauge >= 0 ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 240 } }

            readonly property real radius: Theme.px(Logic.BAR_RADIUS)
            // From 165° round the bottom to 15°
            readonly property real start: 165
            readonly property real span: 150
            property real level: Math.max(0, window.pageView.gauge)
            // Follows a drag on the slider at once
            Behavior on level { enabled: !(grip.pressed && grip.sliding); NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }

            ShapePath {
                fillColor: "transparent"
                strokeColor: Theme.overlay(0.12)
                strokeWidth: Theme.px(6)
                capStyle: ShapePath.RoundCap
                PathAngleArc { radiusX: gauge.radius; radiusY: gauge.radius; startAngle: gauge.start; sweepAngle: -gauge.span }
            }
            ShapePath {
                fillColor: "transparent"
                strokeColor: window.pageView.color
                strokeWidth: Theme.px(6)
                capStyle: ShapePath.RoundCap
                PathAngleArc { radiusX: gauge.radius; radiusY: gauge.radius; startAngle: gauge.start; sweepAngle: -gauge.span * gauge.level }
            }
        }

        // The slider's knob, at the end of the gauge's fill
        Rectangle {
            readonly property var at: Logic.point(gauge.radius, gauge.start - gauge.span * gauge.level)
            width: Theme.px(14)
            height: width
            radius: width / 2
            x: window.cx + at.x - width / 2
            y: window.cy + at.y - height / 2
            color: window.pageView.color
            border.width: Theme.px(3)
            border.color: Theme.dockGlass ? Theme.glassFill : Theme.islandBackground
            opacity: window.pageView.slider ? gauge.opacity : 0
            visible: opacity > 0
            scale: grip.pressed && grip.sliding ? 1.3 : 1
            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
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
                            // A page's action tile: armed waits for its second click, on is a
                            // toggle that is on
                            id: tile
                            readonly property bool isAction: slot.app.kind === "action"
                            readonly property bool armed: isAction && DialService.armedAction === slot.app.id
                            readonly property bool on: isAction && (!!slot.app.lit || (!!slot.app.toggle && DialService.actionOn(slot.app)))
                            readonly property color tint: armed ? Theme.accentRed : Theme.accentBlue

                            width: Theme.px(84)
                            height: Theme.px(84)
                            radius: Theme.px(14)
                            color: armed ? Qt.alpha(Theme.accentRed, 0.28)
                                : slot.selected ? Qt.alpha(Theme.accentBlue, 0.24) : Theme.overlay(tileHover.hovered ? 0.08 : 0)
                            border.width: 1
                            opacity: isAction && !DialService.actionEnabled(slot.app) ? 0.4 : 1
                            Behavior on color { ColorAnimation { duration: 120 } }

                            HoverHandler { id: tileHover }
                            border.color: armed ? Qt.alpha(Theme.accentRed, 0.7) : slot.selected ? Qt.alpha(tint, 0.6) : "transparent"

                            Column {
                                anchors.centerIn: parent
                                // Up a little, to leave the running dot room
                                anchors.verticalCenterOffset: -Theme.px(3)
                                spacing: Theme.px(4)

                                Image {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    visible: !tile.isAction
                                    width: Theme.px(40)
                                    height: width
                                    sourceSize: Qt.size(width, height)
                                    source: visible ? Quickshell.iconPath(slot.app.icon, slot.app.fallback) : ""
                                }
                                // An action's icon, in a disc of its colour; filled while on or armed
                                Rectangle {
                                    readonly property color tint: tile.armed ? Theme.accentRed : (Theme[slot.app.tint] || Theme.accentBlue)
                                    readonly property bool filled: tile.on || tile.armed
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    visible: tile.isAction
                                    width: Theme.px(40)
                                    height: width
                                    radius: width / 2
                                    color: filled ? tint : Qt.alpha(tint, 0.2)
                                    Behavior on color { ColorAnimation { duration: 120 } }

                                    SvgIcon {
                                        anchors.centerIn: parent
                                        name: parent.visible ? slot.app.icon : ""
                                        size: Theme.px(18)
                                        color: parent.filled ? "#ffffff" : parent.tint
                                    }
                                }
                                Text {
                                    width: Theme.px(76)
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                    text: tile.armed ? "Click again" : slot.app.name
                                    color: Theme.textPrimary
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontPx(10)
                                    font.bold: slot.selected
                                }
                                Text {
                                    width: Theme.px(76)
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                    visible: DialService.searching || slot.app.kind === "window" || slot.app.kind === "process" || slot.app.kind === "notification" || (tile.isAction && !!slot.app.sub)
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

        // Search field, with what the selected hit is, or the category, on the line below.
        // Hidden on a page by opacity alone, so the field keeps the keys.
        Column {
            opacity: DialService.page === "" ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 180 } }
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
                        // A sheet takes the keys from the rings; Esc closes it
                        if (statusIcons.cardMenu !== "") {
                            if (event.key === Qt.Key_Escape) statusIcons.dismissCard();
                            event.accepted = true;
                            return;
                        }
                        // A page has no search: only the keys that move round the dial work there
                        if (DialService.page !== "" && window.pageKeys.indexOf(event.key) < 0) {
                            event.accepted = true;
                            return;
                        }
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
                            // Back from a page, else clears the search first, then closes
                            if (DialService.page !== "") DialService.togglePage(DialService.page);
                            else if (DialService.searching) DialService.setQuery("");
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

        // A page's readout, where the search field is: a title and a status line
        Column {
            x: window.cx - width / 2
            y: window.cy + Theme.px(22)
            width: Theme.px(320)
            spacing: Theme.px(2)
            opacity: DialService.page !== "" ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 180 } }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: window.pageView.title
                color: window.pageView.titleColor
                font.family: Theme.fontDisplay
                font.pixelSize: Theme.fontPx(window.pageView.titleSize)
                font.bold: true
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                visible: DialService.passwordFor === ""
                text: window.pageView.status
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontPx(11)
            }

            // The Wi-Fi page's password field, for a secured network that is not saved.
            // Enter connects, Esc cancels; either gives the keys back to the dial.
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: DialService.passwordFor !== ""
                width: Theme.px(260)
                height: password.height + Theme.px(8)
                radius: height / 2
                color: "transparent"
                border.width: 1
                border.color: password.activeFocus ? Qt.alpha(Theme.accentBlue, 0.7) : Theme.glassHairline

                onVisibleChanged: {
                    password.text = "";
                    if (visible) password.forceActiveFocus();
                    else input.forceActiveFocus();
                }

                TextInput {
                    id: password
                    anchors.centerIn: parent
                    width: parent.width - Theme.px(32)
                    horizontalAlignment: TextInput.AlignHCenter
                    echoMode: TextInput.Password
                    color: Theme.textPrimary
                    selectionColor: Theme.accentBlue
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontPx(15)
                    clip: true

                    Text {
                        anchors.fill: parent
                        horizontalAlignment: Text.AlignHCenter
                        visible: password.text === ""
                        text: "Password"
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: password.font.pixelSize
                        font.weight: Font.Light
                    }

                    Keys.onPressed: event => {
                        // Hiding the field hands the keys back (onVisibleChanged)
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            DialService.submitPassword(password.text);
                        } else if (event.key === Qt.Key_Escape) {
                            DialService.passwordFor = "";
                        } else {
                            return;
                        }
                        event.accepted = true;
                    }
                }
            }
        }

        // Status icons under the search field (dialStatusIcons, a test): the system icons,
        // then the optional ones below a thin line. An icon opens its page of the dial.
        Column {
            id: statusIcons
            readonly property bool active: SettingsService.dialStatusIcons
            visible: active
            x: window.cx - width / 2
            y: window.cy + Theme.px(96)
            spacing: Theme.px(6)

            // StatusIconSet's host interface
            readonly property bool hoverEnabled: true
            // An open page lights its icon (the power page the battery's)
            readonly property string openMenu: DialService.page === "power" ? "battery" : (DialService.page || cardMenu)
            property string unavailableTip: ""
            property Item unavailableTipItem: null
            // An icon opens its page (Logic.pageFor), or its sheet when the page is not ready
            function toggleMenu(id) {
                let was = cardMenu;
                closeMenu();
                let page = Logic.pageFor(id);
                // Hue pairs with its bridge in its sheet
                if (id === "hue" && !HueService.paired) page = "";
                if (page !== "") {
                    DialService.togglePage(page);
                    if (DialService.page !== "") dialIconSet.prepareMenu(id === "battery" ? "profile" : id);
                    return;
                }
                if (id === "" || id === was) return;
                cardMenu = id;
            }

            // The sheet shown over the disc (statusMenu), by its icon's id, or "". cardReturn
            // is the page it was opened from, which closing it goes back to.
            property string cardMenu: ""
            property string cardReturn: ""
            function closeMenu() {
                menu.entries = [];
                cardMenu = "";
                cardReturn = "";
                // A field in the menu may have taken the keys
                input.forceActiveFocus();
            }

            // Closes the sheet and goes back to the page it came from
            function dismissCard() {
                // The Hue page is only for a paired bridge
                let back = cardReturn === "hue" && !HueService.paired ? "" : cardReturn;
                closeMenu();
                if (back !== "" && DialService.page !== back) DialService.togglePage(back);
            }

            Connections {
                target: DialService
                function onOpenChanged() {
                    if (!DialService.open) statusIcons.closeMenu();
                }
                // A page's tile for what only the card holds (Hue's bridge, custom hours)
                function onCardRequested(id) {
                    let from = DialService.page;
                    if (from !== "") DialService.togglePage(from);
                    statusIcons.cardMenu = id;
                    statusIcons.cardReturn = from;
                }
            }

            StatusIconSet {
                id: dialIconSet
                host: statusIcons
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.px(4)
                Repeater {
                    model: statusIcons.active ? dialIconSet.systemIcons : []
                    delegate: dialIconSet.delegate
                }
            }

            // Parts the system icons from the optional ones
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Theme.px(160)
                height: 1
                color: Theme.glassHairline
                visible: dialIconSet.showWidgets && dialIconSet.visibleIconCount > dialIconSet.widgetCount
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.px(4)
                Repeater {
                    model: statusIcons.active ? dialIconSet.widgetIcons : []
                    delegate: dialIconSet.delegate
                }
            }

            // Names the missing tool of a dimmed icon under the pointer
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: statusIcons.unavailableTipItem !== null && statusIcons.unavailableTip !== ""
                text: statusIcons.unavailableTip
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

    // Whether a point of `hit` is on the open page's slider, and the level there
    function overSlider(x, y) {
        return !!window.pageView.slider && Logic.onGauge(x + hit.x - window.cx, y + hit.y - window.cy,
            gauge.radius, Theme.px(Logic.SLIDER_BAND), gauge.start, gauge.span);
    }

    function sliderAt(x, y) {
        return Logic.gaugeAt(x + hit.x - window.cx, y + hit.y - window.cy, gauge.start, gauge.span, false);
    }

    // Wheel turns the ring or the arc, whichever the pointer is over, or moves a page's slider
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
            let slider = window.overSlider(wheel.x, wheel.y);
            let spinner = slider ? null : window.spinnerAt(wheel.x, wheel.y);
            if (spinner !== over || now - time > 400) carry = 0;
            over = spinner;
            time = now;
            // Down or right is forward. A touchpad's lift-off event has no delta and turns nothing.
            let delta = wheel.angleDelta.y !== 0 ? -wheel.angleDelta.y : -wheel.angleDelta.x;
            let turn = Logic.wheelSteps(carry, delta);
            carry = turn.carry;
            if (turn.steps === 0) return;
            // Up raises the slider
            if (slider) DialService.setSlider(Logic.clamp(window.pageView.gauge - turn.steps * (Pages.SLIDER_STEP[DialService.page] || 0.05), 0, 1));
            else if (spinner === ringSpin) DialService.setRing(window.ringIndex + turn.steps);
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

        // The Spinner under the press, or the page's slider (`sliding`)
        property var turner: null
        property bool sliding: false
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
            sliding = window.overSlider(mouse.x, mouse.y);
            if (sliding) {
                turner = null;
                DialService.setSlider(window.sliderAt(mouse.x, mouse.y));
                return;
            }
            turner = window.spinnerAt(mouse.x, mouse.y);
            pressX = mouse.x;
            pressY = mouse.y;
        }

        onPositionChanged: mouse => {
            if (sliding) {
                DialService.setSlider(window.sliderAt(mouse.x, mouse.y));
                return;
            }
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
        onClicked: mouse => mouse.accepted = dragged || sliding
    }

    // Clicking the pill in the middle of the disc closes it, as clicking the pill opened it
    MouseArea {
        x: window.cx - Theme.compactWidthClock / 2
        y: window.pillTop
        width: Theme.compactWidthClock
        height: window.pillHeight
        enabled: window.shown
        cursorShape: Qt.PointingHandCursor
        // From a page it goes back to the launcher
        onClicked: {
            if (DialService.page !== "") DialService.togglePage(DialService.page);
            else DialService.close();
        }
    }

    // While a status icon's menu is open, a press or wheel anywhere else closes the menu
    // (not the dial) and the rings under it stay put
    MouseArea {
        anchors.fill: parent
        enabled: window.shown && statusIcons.cardMenu !== ""
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onPressed: statusIcons.dismissCard()
        onWheel: wheel => wheel.accepted = true
    }

    // A page's sheet (DialSheet), over the disc below the pill
    Rectangle {
        id: statusMenu
        readonly property bool isOpen: statusIcons.cardMenu !== ""
        // The sheet last shown, kept while it fades out
        property string shownId: ""
        width: Theme.px(340)
        height: sheetLoader.height
        x: window.cx - width / 2
        y: window.pillTop + window.pillHeight + Theme.px(14)
        radius: Theme.px(26)
        color: Theme.menuSurface
        border.width: 1
        border.color: Theme.glassHairline
        clip: true
        opacity: isOpen ? 1 : 0
        scale: isOpen ? 1 : 0.96
        transformOrigin: Item.Top
        visible: opacity > 0.01
        enabled: isOpen

        Behavior on opacity { NumberAnimation { duration: Theme.animDurationFast } }
        Behavior on scale { NumberAnimation { duration: Theme.animDurationFast; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: Theme.animDurationFast; easing.type: Easing.OutCubic } }

        Connections {
            target: statusIcons
            function onCardMenuChanged() {
                if (statusIcons.cardMenu !== "") statusMenu.shownId = statusIcons.cardMenu;
            }
        }

        // Swallows presses on the sheet's own background, so they do not reach the catcher
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onWheel: wheel => wheel.accepted = true
        }

        // The sheets, by the icon whose page opens them
        readonly property var components: ({
            "hue": hueSheet,
            "nightLight": nightSheet,
            "kdeConnect": sendSheet
        })

        Loader {
            id: sheetLoader
            // Its height follows the sheet's
            width: parent.width
            active: statusMenu.shownId !== "" && statusMenu.visible
            sourceComponent: statusMenu.components[statusMenu.shownId] || null
            onLoaded: (item as DialSheet).takeFocus()
        }

        Connections {
            target: sheetLoader.item
            function onCloseRequested() { statusIcons.dismissCard(); }
            function onPageRequested(page) {
                statusIcons.closeMenu();
                if (DialService.page !== page) DialService.togglePage(page);
            }
        }

        Component { id: hueSheet; HueBridgeSheet {} }
        Component { id: nightSheet; NightHoursSheet {} }
        Component { id: sendSheet; SendTextSheet {} }
    }

    // Right-click menu of a tile, over everything else
    DialMenu {
        id: menu
        onChosen: entry => window.runMenuEntry(entry)
    }
}
