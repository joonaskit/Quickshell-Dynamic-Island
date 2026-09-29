import QtQuick

Item {
    id: root

    property real targetX: 0
    property real targetWidth: 100
    property bool active: false
    property color accentColor: Theme.accentBlue

    // Purely visual overlay - do not intercept clicks.
    // Anchored at the top screen edge and follows the hidden element's horizontal footprint.
    anchors.top: parent.top
    x: root.targetX
    width: root.targetWidth
    implicitHeight: Theme.px(26)

    // Smooth entrance and exit animations
    opacity: root.active ? 1.0 : 0.0
    visible: opacity > 0.005

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.animDurationFast
            easing.type: Easing.OutCubic
        }
    }

    Behavior on x {
        NumberAnimation {
            duration: Theme.animDuration
            easing.type: Easing.OutCubic
        }
    }

    Behavior on width {
        NumberAnimation {
            duration: Theme.animDuration
            easing.type: Theme.animEasing
            easing.overshoot: Theme.animOvershoot
        }
    }

    // Gentle breathing luma factor while mouse is near
    property real pulseFactor: 1.0

    SequentialAnimation on pulseFactor {
        running: root.active
        loops: Animation.Infinite
        NumberAnimation { to: 0.70; duration: 950; easing.type: Easing.InOutSine }
        NumberAnimation { to: 1.00; duration: 950; easing.type: Easing.InOutSine }
    }

    // Layer 1: Soft Ambient Colored Halo
    Rectangle {
        id: ambientHalo
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width + Theme.px(14)
        height: Theme.px(24)

        bottomLeftRadius: Theme.px(12)
        bottomRightRadius: Theme.px(12)

        opacity: root.pulseFactor

        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.32)
            }
            GradientStop {
                position: 0.45
                color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.10)
            }
            GradientStop {
                position: 1.0
                color: "transparent"
            }
        }
    }

    // Layer 2: Inner Diffuse White Glow (Apple OLED luminance)
    Rectangle {
        id: innerWhiteGlow
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width
        height: Theme.px(14)

        bottomLeftRadius: Theme.px(7)
        bottomRightRadius: Theme.px(7)

        opacity: 0.65 + 0.35 * root.pulseFactor

        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(1.0, 1.0, 1.0, 0.28) }
            GradientStop { position: 0.4; color: Qt.rgba(1.0, 1.0, 1.0, 0.09) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    // Layer 3: Specular Edge Beam (Crisp glass refraction at the screen bezel)
    Rectangle {
        id: edgeBeam
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.max(Theme.px(24), parent.width - Theme.px(8))
        height: Theme.px(2.5)

        bottomLeftRadius: Theme.px(1.5)
        bottomRightRadius: Theme.px(1.5)

        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.10) }
            GradientStop { position: 0.2; color: Qt.rgba(1, 1, 1, 0.70) }
            GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.95) }
            GradientStop { position: 0.8; color: Qt.rgba(1, 1, 1, 0.70) }
            GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.10) }
        }
    }

    // Layer 4: Accent Color Core Line (Gives distinct color identity to the element)
    Rectangle {
        id: accentLine
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.max(Theme.px(16), parent.width - Theme.px(16))
        height: Theme.px(1.5)

        bottomLeftRadius: Theme.px(1)
        bottomRightRadius: Theme.px(1)

        opacity: 0.85

        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.25; color: root.accentColor }
            GradientStop { position: 0.50; color: Qt.lighter(root.accentColor, 1.35) }
            GradientStop { position: 0.75; color: root.accentColor }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }
}
