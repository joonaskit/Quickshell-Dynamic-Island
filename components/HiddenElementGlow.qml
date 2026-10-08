import ".."
import QtQuick
import Qt5Compat.GraphicalEffects

Item {
    id: root

    property real targetX: 0
    property real targetWidth: 100
    property bool active: false
    property color accentColor: Theme.accent
    property bool atBottom: false

    // Purely visual overlay - do not intercept clicks.
    // Anchored at top or bottom screen edge and follows the hidden element's horizontal footprint.
    anchors.top: root.atBottom ? undefined : parent.top
    anchors.bottom: root.atBottom ? parent.bottom : undefined
    x: root.targetX
    width: root.targetWidth
    implicitHeight: Theme.px(48)

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

    // Layer 1: Soft Feathered Ambient Colored Halo (Radiates out as a round diffuse aura)
    RectangularGlow {
        id: ambientHalo
        anchors.top: root.atBottom ? undefined : parent.top
        anchors.bottom: root.atBottom ? parent.bottom : undefined
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: root.atBottom ? 0 : -height / 2
        anchors.bottomMargin: root.atBottom ? -height / 2 : 0
        width: parent.width + Theme.px(24)
        height: Theme.px(24)

        glowRadius: Theme.px(38)
        spread: 0.08
        color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.70)
        cornerRadius: height / 2 + glowRadius

        opacity: root.pulseFactor
    }

    // Layer 2: Inner Diffuse White Glow (OLED high-luminance core)
    RectangularGlow {
        id: innerWhiteGlow
        anchors.top: root.atBottom ? undefined : parent.top
        anchors.bottom: root.atBottom ? parent.bottom : undefined
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: root.atBottom ? 0 : -height / 2
        anchors.bottomMargin: root.atBottom ? -height / 2 : 0
        width: parent.width
        height: Theme.px(16)

        glowRadius: Theme.px(16)
        spread: 0.15
        color: Theme.overlay(0.55)
        cornerRadius: height / 2 + glowRadius

        opacity: 0.55 + 0.35 * root.pulseFactor
    }

    // Layer 3: Specular Edge Pill (Crisp rounded glass highlight at bezel)
    Rectangle {
        id: edgeBeam
        anchors.top: root.atBottom ? undefined : parent.top
        anchors.bottom: root.atBottom ? parent.bottom : undefined
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.max(Theme.px(28), parent.width - Theme.px(12))
        height: Theme.px(3)
        radius: height / 2

        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.20; color: Qt.rgba(1, 1, 1, 0.45) }
            GradientStop { position: 0.50; color: Qt.rgba(1, 1, 1, 0.90) }
            GradientStop { position: 0.80; color: Qt.rgba(1, 1, 1, 0.45) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    // Layer 4: Accent Color Core Glow Pill (Gives distinct color identity to the element)
    Rectangle {
        id: accentLine
        anchors.top: root.atBottom ? undefined : parent.top
        anchors.bottom: root.atBottom ? parent.bottom : undefined
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.max(Theme.px(20), parent.width - Theme.px(20))
        height: Theme.px(2)
        radius: height / 2

        opacity: 0.90

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
