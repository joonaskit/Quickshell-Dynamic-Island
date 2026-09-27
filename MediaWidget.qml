import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property var player: null
    property bool isPlaying: player ? player.isPlaying : false
    property string trackTitle: player && player.trackTitle ? player.trackTitle : "Not Playing"
    property string trackArtist: player && player.trackArtist ? player.trackArtist : "No Media"
    property string trackAlbum: player && player.trackAlbum ? player.trackAlbum : ""
    property string artUrl: player && player.trackArtUrl ? player.trackArtUrl : ""
    property real trackLength: player && player.length ? player.length : 0
    property real trackPosition: player && player.position ? player.position : 0

    implicitHeight: 96
    implicitWidth: parent ? parent.width : 370

    // Timer to update track position regularly while playing
    Timer {
        interval: 500
        running: root.isPlaying && root.visible
        repeat: true
        onTriggered: {
            if (root.player) {
                // Reading position updates it
                root.trackPosition = root.player.position;
            }
        }
    }

    Connections {
        target: root.player
        function onPositionChanged() {
            if (root.player) {
                root.trackPosition = root.player.position;
            }
        }
    }

    function formatTime(sec) {
        if (!sec || isNaN(sec) || sec < 0) return "0:00";
        let m = Math.floor(sec / 60);
        let s = Math.floor(sec % 60);
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    RowLayout {
        id: topRow
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 12

        // Album Art
        Rectangle {
            Layout.preferredWidth: 48
            Layout.preferredHeight: 48
            radius: 10
            color: "#1c1c1e"
            border.color: Qt.rgba(1, 1, 1, 0.1)
            border.width: 1
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
                size: 22
                color: Theme.accentOrange
                visible: root.artUrl === "" || parent.children[0].status !== Image.Ready
            }
        }

        // Title and Artist
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                text: root.trackTitle
                font.family: Theme.fontDisplay
                font.pixelSize: 13
                font.weight: Font.DemiBold
                color: Theme.textPrimary
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                text: root.trackArtist + (root.trackAlbum ? " • " + root.trackAlbum : "")
                font.family: Theme.fontFamily
                font.pixelSize: 11
                color: Theme.textSecondary
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }

        // Transport Controls
        Row {
            spacing: 4
            Layout.alignment: Qt.AlignVCenter

            // Previous button
            Rectangle {
                width: 30
                height: 30
                radius: 15
                color: prevArea.containsMouse ? Theme.controlBackgroundHover : "transparent"

                SvgIcon {
                    anchors.centerIn: parent
                    name: "previous"
                    size: 14
                    color: Theme.textPrimary
                }

                MouseArea {
                    id: prevArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.player && root.player.canGoPrevious) {
                            root.player.previous();
                        }
                    }
                }
            }

            // Play / Pause button (filled prominent circle)
            Rectangle {
                width: 32
                height: 32
                radius: 16
                color: playArea.containsMouse ? Qt.rgba(1, 1, 1, 0.95) : Qt.rgba(1, 1, 1, 0.85)

                SvgIcon {
                    anchors.centerIn: parent
                    name: root.isPlaying ? "pause" : "play"
                    size: 14
                    color: "#000000"
                }

                MouseArea {
                    id: playArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.player) {
                            root.player.togglePlaying();
                        }
                    }
                }
            }

            // Next button
            Rectangle {
                width: 30
                height: 30
                radius: 15
                color: nextArea.containsMouse ? Theme.controlBackgroundHover : "transparent"

                SvgIcon {
                    anchors.centerIn: parent
                    name: "next"
                    size: 14
                    color: Theme.textPrimary
                }

                MouseArea {
                    id: nextArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.player && root.player.canGoNext) {
                            root.player.next();
                        }
                    }
                }
            }
        }
    }

    // Seek / Progress Bar Row
    ColumnLayout {
        anchors.top: topRow.bottom
        anchors.topMargin: 8
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 3

        // Seek Bar Track
        Rectangle {
            id: trackBar
            Layout.fillWidth: true
            Layout.preferredHeight: 5
            radius: 2.5
            color: Theme.sliderTrack

            // Fill Bar
            Rectangle {
                id: fillBar
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                radius: 2.5
                color: seekArea.containsMouse ? Theme.accentGreen : Theme.textPrimary
                width: root.trackLength > 0 ? Math.min(trackBar.width, Math.max(0, (root.trackPosition / root.trackLength) * trackBar.width)) : 0

                Behavior on color {
                    ColorAnimation { duration: 150 }
                }
            }

            MouseArea {
                id: seekArea
                anchors.fill: parent
                anchors.margins: -4 // larger hit area
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: function(mouse) {
                    if (root.player && root.trackLength > 0 && root.player.canSeek) {
                        let ratio = Math.max(0, Math.min(1, mouse.x / trackBar.width));
                        let targetSec = ratio * root.trackLength;
                        let offset = targetSec - (root.player.position || 0);
                        root.player.seek(offset);
                    }
                }
            }
        }

        // Time labels
        RowLayout {
            Layout.fillWidth: true

            Text {
                text: root.formatTime(root.trackPosition)
                font.family: Theme.fontFamily
                font.pixelSize: 10
                font.features: { "tnum": 1 }
                color: Theme.textTertiary
            }

            Item { Layout.fillWidth: true }

            Text {
                text: root.formatTime(root.trackLength)
                font.family: Theme.fontFamily
                font.pixelSize: 10
                font.features: { "tnum": 1 }
                color: Theme.textTertiary
            }
        }
    }
}
