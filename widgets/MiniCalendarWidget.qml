import ".."
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    // Set by the expanded view; provides currentTime
    property var host: null
    property date currentDate: host ? host.currentTime : new Date()
    property int displayYear: currentDate.getFullYear()
    property int displayMonth: currentDate.getMonth() // 0-indexed

    implicitWidth: parent ? parent.width : Theme.px(370)
    implicitHeight: mainLayout.implicitHeight

    readonly property var monthNames: [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"
    ]

    readonly property var dayHeaders: ["Wk", "Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

    function isSameDay(d1, d2) {
        return d1.getFullYear() === d2.getFullYear() &&
               d1.getMonth() === d2.getMonth() &&
               d1.getDate() === d2.getDate();
    }

    function getIsoWeekNumber(d) {
        let target = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
        let dayNum = target.getUTCDay() || 7;
        target.setUTCDate(target.getUTCDate() + 4 - dayNum);
        let yearStart = new Date(Date.UTC(target.getUTCFullYear(), 0, 1));
        return Math.ceil((((target - yearStart) / 86400000) + 1) / 7);
    }

    // Build the 6-week matrix (each week has weekNumber + 7 days)
    readonly property var calendarWeeks: {
        let weeks = [];
        let firstDayOfMonth = new Date(displayYear, displayMonth, 1);
        let dayOfWeek = firstDayOfMonth.getDay(); // 0 is Sunday
        let offset = (dayOfWeek === 0) ? 6 : (dayOfWeek - 1); // Monday is 0

        let startDate = new Date(displayYear, displayMonth, 1 - offset);

        for (let w = 0; w < 6; w++) {
            let weekDays = [];
            let weekDate = new Date(startDate.getFullYear(), startDate.getMonth(), startDate.getDate() + (w * 7));
            let weekNum = getIsoWeekNumber(weekDate);

            for (let d = 0; d < 7; d++) {
                let cellDate = new Date(startDate.getFullYear(), startDate.getMonth(), startDate.getDate() + (w * 7) + d);
                weekDays.push({
                    day: cellDate.getDate(),
                    month: cellDate.getMonth(),
                    year: cellDate.getFullYear(),
                    isCurrentMonth: (cellDate.getMonth() === displayMonth),
                    isToday: isSameDay(cellDate, currentDate)
                });
            }

            // If the 6th week belongs entirely to next month, skip it
            if (w === 5 && !weekDays[0].isCurrentMonth) {
                break;
            }

            weeks.push({
                weekNumber: weekNum,
                isCurrentWeek: weekDays.some(d => d.isToday),
                days: weekDays
            });
        }
        return weeks;
    }

    ColumnLayout {
        id: mainLayout
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Theme.px(8)

        // Month & Navigation Header
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.px(6)

            // Calendar Icon & Title
            RowLayout {
                spacing: Theme.px(6)
                SvgIcon {
                    name: "calendar"
                    size: Theme.px(13)
                    color: Theme.accentBlue
                }

                Text {
                    text: root.monthNames[root.displayMonth] + " " + root.displayYear
                    font.family: Theme.fontDisplay
                    font.pixelSize: Theme.fontPx(12)
                    font.weight: Font.DemiBold
                    color: Theme.textPrimary
                }
            }

            Item { Layout.fillWidth: true }

            // Today Jump Button
            Rectangle {
                Layout.preferredHeight: Theme.px(20)
                Layout.preferredWidth: todayText.implicitWidth + Theme.px(12)
                radius: Theme.px(10)
                color: todayMouse.containsMouse ? Qt.rgba(10/255, 132/255, 255/255, 0.25) : Qt.rgba(1, 1, 1, 0.06)
                visible: (root.displayYear !== root.currentDate.getFullYear() || root.displayMonth !== root.currentDate.getMonth())

                Text {
                    id: todayText
                    anchors.centerIn: parent
                    text: "Today"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontPx(10)
                    font.weight: Font.DemiBold
                    color: Theme.accentBlue
                }

                MouseArea {
                    id: todayMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.displayYear = root.currentDate.getFullYear();
                        root.displayMonth = root.currentDate.getMonth();
                    }
                }
            }

            // Prev Month Button
            Rectangle {
                Layout.preferredWidth: Theme.px(22)
                Layout.preferredHeight: Theme.px(22)
                radius: Theme.px(11)
                color: prevMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                scale: prevMouse.pressed ? 0.90 : 1.0

                SvgIcon {
                    anchors.centerIn: parent
                    name: "chevron-left"
                    size: Theme.px(12)
                    color: Theme.textSecondary
                }

                MouseArea {
                    id: prevMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.displayMonth === 0) {
                            root.displayMonth = 11;
                            root.displayYear -= 1;
                        } else {
                            root.displayMonth -= 1;
                        }
                    }
                }
            }

            // Next Month Button
            Rectangle {
                Layout.preferredWidth: Theme.px(22)
                Layout.preferredHeight: Theme.px(22)
                radius: Theme.px(11)
                color: nextMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                scale: nextMouse.pressed ? 0.90 : 1.0

                SvgIcon {
                    anchors.centerIn: parent
                    name: "chevron-right"
                    size: Theme.px(12)
                    color: Theme.textSecondary
                }

                MouseArea {
                    id: nextMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.displayMonth === 11) {
                            root.displayMonth = 0;
                            root.displayYear += 1;
                        } else {
                            root.displayMonth += 1;
                        }
                    }
                }
            }
        }

        // Calendar Grid Container Card
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: gridColumn.implicitHeight + Theme.px(12)
            radius: Theme.px(12)
            color: Qt.rgba(1, 1, 1, 0.03)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.06)

            ColumnLayout {
                id: gridColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Theme.px(6)
                spacing: Theme.px(2)

                // Header Row: Wk, Mo, Tu, We, Th, Fr, Sa, Su
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Repeater {
                        model: root.dayHeaders

                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: Theme.px(20)

                            Text {
                                anchors.centerIn: parent
                                text: modelData
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontPx(10)
                                font.weight: Font.DemiBold
                                color: (index === 0) ? Theme.accentOrange : ((index >= 6) ? Theme.textSecondary : Theme.textTertiary)
                            }
                        }
                    }
                }

                // Divider line below day names
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Qt.rgba(1, 1, 1, 0.06)
                }

                // Weeks and Days Grid
                Repeater {
                    model: root.calendarWeeks

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Theme.px(24)
                        spacing: 0

                        // 1. Week Number Column (Wk)
                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            Rectangle {
                                anchors.centerIn: parent
                                width: Theme.px(22)
                                height: Theme.px(18)
                                radius: Theme.px(4)
                                color: modelData.isCurrentWeek ? Qt.rgba(255/255, 159/255, 10/255, 0.18) : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.weekNumber
                                    font.family: Theme.fontDisplay
                                    font.pixelSize: Theme.fontPx(9)
                                    font.weight: modelData.isCurrentWeek ? Font.Bold : Font.Normal
                                    font.features: { "tnum": 1 }
                                    color: modelData.isCurrentWeek ? Theme.accentOrange : Qt.rgba(1, 1, 1, 0.3)
                                }
                            }
                        }

                        // 2. Seven Days of this Week
                        Repeater {
                            model: modelData.days

                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                Rectangle {
                                    id: dayBadge
                                    anchors.centerIn: parent
                                    width: Theme.px(22)
                                    height: Theme.px(22)
                                    radius: Theme.px(11)
                                    color: {
                                        if (modelData.isToday) return Theme.accentBlue;
                                        if (cellMouse.containsMouse) return Qt.rgba(1, 1, 1, 0.1);
                                        return "transparent";
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.day
                                        font.family: Theme.fontDisplay
                                        font.pixelSize: Theme.fontPx(10)
                                        font.weight: modelData.isToday ? Font.Bold : Font.Normal
                                        font.features: { "tnum": 1 }
                                        color: {
                                            if (modelData.isToday) return "#ffffff";
                                            if (!modelData.isCurrentMonth) return Qt.rgba(1, 1, 1, 0.18);
                                            return Theme.textPrimary;
                                        }
                                    }

                                    MouseArea {
                                        id: cellMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.ArrowCursor
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
