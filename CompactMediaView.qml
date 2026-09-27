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
    implicitWidth: contentRow.implicitWidth + 20

    RowLayout {
        id: contentRow
        anchors.centerIn: parent
        spacing: 9

        // Album art thumbnail or music icon
        Rectangle {
            Layout.preferredWidth: 22
            Layout.preferredHeight: 22
            Layout.alignment: Qt.AlignVCenter
            radius: 5
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
                size: 13
                color: Theme.accentOrange
                visible: root.artUrl === "" || parent.children[0].status !== Image.Ready
            }
        }

        // Center: time or compact title
        Text {
            id: infoText
            text: Qt.formatDateTime(root.currentTime, "hh:mm")
            font.family: Theme.fontDisplay
            font.pixelSize: 14
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
            maxHeight: 14
            minHeight: 3
            barWidth: 2.5
        }
    }
}
