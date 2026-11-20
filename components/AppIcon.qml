import ".."
import QtQuick

// An app's icon: an icon theme name or a path, with a tile showing the first letter
// of the app's name while there is none or it can't be loaded (e.g. a game whose
// app id names no icon).
Item {
    id: root

    property string icon: ""
    property string name: ""
    // Pixel size the image is decoded at
    property int sourceSize: 128
    property bool asynchronous: false
    readonly property bool loaded: image.status === Image.Ready

    Image {
        id: image
        anchors.fill: parent
        source: DockService.resolveIcon(root.icon)
        sourceSize.width: root.sourceSize
        sourceSize.height: root.sourceSize
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
        asynchronous: root.asynchronous
        visible: root.loaded
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.corner(root.height / 4)
        visible: !root.loaded
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.tileGradientTop }
            GradientStop { position: 1.0; color: Theme.tileGradientBottom }
        }
        border.color: Theme.overlay(0.15)
        border.width: 1

        Text {
            anchors.centerIn: parent
            text: root.name ? root.name.charAt(0).toUpperCase() : "?"
            font.family: Theme.fontDisplay
            font.pixelSize: Math.max(8, Math.round(root.height * 0.41))
            font.weight: Font.Bold
            color: Theme.textPrimary
        }
    }
}
