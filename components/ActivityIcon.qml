import ".."
import QtQuick
import Quickshell

// An activity's icon: an icon theme name or an absolute file path, with a
// glyph shown while there is none or it can't be loaded.
Item {
    id: root

    property string icon: ""
    property string fallback: "download"
    property real size: Theme.px(20)
    property color color: Theme.textPrimary

    implicitWidth: size
    implicitHeight: size
    width: size
    height: size

    Image {
        id: image
        anchors.fill: parent
        sourceSize: Qt.size(root.size * 2, root.size * 2)
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        source: {
            if (root.icon === "") return "";
            return root.icon.startsWith("/") ? "file://" + root.icon : Quickshell.iconPath(root.icon, true);
        }
        visible: status === Image.Ready
    }

    SvgIcon {
        anchors.centerIn: parent
        visible: !image.visible
        name: root.fallback
        size: root.size * 0.8
        color: root.color
    }
}
