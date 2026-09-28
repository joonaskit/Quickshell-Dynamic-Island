import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property var player: null
    property date currentTime: new Date()
    property bool isPlaying: player ? player.isPlaying : false
    property string trackTitle: player && player.trackTitle ? player.trackTitle : "No Media"
    property string artUrl: player && player.trackArtUrl ? player.trackArtUrl : ""

    implicitHeight: Theme.compactHeight
    implicitWidth: contentRow.implicitWidth + Theme.px(20)

    RowLayout {
        id: contentRow
        anchors.centerIn: parent
        spacing: Theme.px(9)

        // Album art thumbnail or music icon
        Rectangle {
            Layout.preferredWidth: Theme.px(22)
            Layout.preferredHeight: Theme.px(22)
            Layout.alignment: Qt.AlignVCenter
            radius: Theme.px(5)
            color: "#1c1c1e"
            clip: true

            Image {
                anchors.fill: parent
                source: root.artUrl
                fillMode: Image.PreserveAspectCrop
                visible: root.artUrl !== "" && status === Image.Ready
                asynchronous: true
            }

            SvgIcon {
                anchors.centerIn: parent
                name: "music"
                size: Theme.px(13)
                color: Theme.accentOrange
                visible: root.artUrl === "" || parent.children[0].status !== Image.Ready
            }
        }

        // Center: time or compact title
        Text {
            id: infoText
            text: Qt.formatDateTime(root.currentTime, "hh:mm")
            font.family: Theme.fontDisplay
            font.pixelSize: Theme.fontPx(14)
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
            color: Theme.textPrimary
            Layout.alignment: Qt.AlignVCenter
        }

        // Right: Animated sound wave bars
        AudioVisualizer {
            Layout.alignment: Qt.AlignVCenter
            playing: root.isPlaying
            barColor: Theme.accentGreen
            maxHeight: Theme.px(14)
            minHeight: Theme.px(3)
            barWidth: Theme.px(2.5)
        }
    }
}
