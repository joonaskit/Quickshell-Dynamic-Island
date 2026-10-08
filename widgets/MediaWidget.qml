import ".."
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    // Set by the expanded view; provides player
    property var host: null
    property var player: host ? host.player : null
    property bool isPlaying: player ? player.isPlaying : false
    property string trackTitle: player && player.trackTitle ? player.trackTitle : "Not Playing"
    property string trackArtist: player && player.trackArtist ? player.trackArtist : "No Media"
    property string trackAlbum: player && player.trackAlbum ? player.trackAlbum : ""
    property string artUrl: player && player.trackArtUrl ? player.trackArtUrl : ""
    property real trackLength: player && player.length ? player.length : 0
    property real trackPosition: player && player.position ? player.position : 0

    implicitHeight: Theme.px(96)
    implicitWidth: parent ? parent.width : Theme.px(370)

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
        spacing: Theme.px(12)

        // Album Art
        Rectangle {
            Layout.preferredWidth: Theme.px(48)
            Layout.preferredHeight: Theme.px(48)
            radius: Theme.px(10)
            color: Theme.cardBackground
            border.color: Theme.overlay(0.1)
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
                size: Theme.px(22)
                color: Theme.accentOrange
                visible: root.artUrl === "" || parent.children[0].status !== Image.Ready
            }
        }

        // Title and Artist
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.px(2)

            Text {
                text: root.trackTitle
                font.family: Theme.fontDisplay
                font.pixelSize: Theme.fontPx(13)
                font.weight: Font.DemiBold
                color: Theme.textPrimary
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                text: root.trackArtist + (root.trackAlbum ? " • " + root.trackAlbum : "")
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontPx(11)
                color: Theme.textSecondary
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }

        // Transport Controls
        Row {
            spacing: Theme.px(4)
            Layout.alignment: Qt.AlignVCenter

            // Previous button
            Rectangle {
                width: Theme.px(30)
                height: Theme.px(30)
                radius: Theme.px(15)
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
                width: Theme.px(32)
                height: Theme.px(32)
                radius: Theme.px(16)
                color: playArea.containsMouse ? Theme.overlay(0.95) : Theme.overlay(0.85)

                SvgIcon {
                    anchors.centerIn: parent
                    name: root.isPlaying ? "pause" : "play"
                    size: Theme.px(14)
                    color: Theme.lightForeground
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
                width: Theme.px(30)
                height: Theme.px(30)
                radius: Theme.px(15)
                color: nextArea.containsMouse ? Theme.controlBackgroundHover : "transparent"

                SvgIcon {
                    anchors.centerIn: parent
                    name: "next"
                    size: Theme.px(14)
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
        anchors.topMargin: Theme.px(8)
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Theme.px(3)

        // Seek Bar Track
        Rectangle {
            id: trackBar
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.px(5)
            radius: Theme.px(2.5)
            color: Theme.sliderTrack

            // Fill Bar
            Rectangle {
                id: fillBar
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                radius: Theme.px(2.5)
                color: seekArea.containsMouse ? Theme.accentGreen : Theme.textPrimary
                width: root.trackLength > 0 ? Math.min(trackBar.width, Math.max(0, (root.trackPosition / root.trackLength) * trackBar.width)) : 0

                Behavior on color {
                    ColorAnimation { duration: 150 }
                }
            }

            MouseArea {
                id: seekArea
                anchors.fill: parent
                anchors.margins: -Theme.px(4) // larger hit area
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
                font.pixelSize: Theme.fontPx(10)
                font.features: { "tnum": 1 }
                color: Theme.textTertiary
            }

            Item { Layout.fillWidth: true }

            Text {
                text: root.formatTime(root.trackLength)
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontPx(10)
                font.features: { "tnum": 1 }
                color: Theme.textTertiary
            }
        }
    }
}
