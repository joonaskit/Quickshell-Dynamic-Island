import ".."
import QtQuick
import QtQuick.Layouts

// One step of the welcome guide: a heading, an intro line and the step's content
// below, scrolling when it is taller than the window
Flickable {
    id: page

    property string title: ""
    property string intro: ""
    default property alias content: contentColumn.data

    contentWidth: width
    contentHeight: pageColumn.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    ColumnLayout {
        id: pageColumn
        width: page.width
        spacing: Theme.px(14)

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.px(4)

            Text {
                Layout.fillWidth: true
                text: page.title
                wrapMode: Text.WordWrap
                font.family: Theme.fontDisplay
                font.pixelSize: Theme.fontPx(20)
                font.weight: Font.DemiBold
                color: Theme.textPrimary
            }

            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: page.intro
                wrapMode: Text.WordWrap
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontPx(12)
                color: Theme.textSecondary
            }
        }

        ColumnLayout {
            id: contentColumn
            Layout.fillWidth: true
            spacing: Theme.px(10)
        }
    }
}
