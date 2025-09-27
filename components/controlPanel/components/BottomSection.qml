import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components.base
import qs.services

Rectangle {
    id: root

    property int bottomTab: 0 // 0 = Calendar, 1 = Notes

    // Calendar properties
    property date currentDate: DateTime.clock.date
    property int currentMonth: currentDate.getMonth()
    property int currentYear: currentDate.getFullYear()
    readonly property int actualYear: currentDate.getFullYear()
    property var calendarData: generateCalendarData(currentMonth, currentYear)
    property bool showDateSelector: false

    function generateCalendarData(month, year) {
        let firstDay = new Date(year, month, 1);
        let lastDay = new Date(year, month + 1, 0);
        let daysInMonth = lastDay.getDate();
        let startDayOfWeek = (firstDay.getDay() + 6) % 7; // Monday = 0

        let calendar = [];

        // Previous month's trailing days
        let prevMonth = month === 0 ? 11 : month - 1;
        let prevYear = month === 0 ? year - 1 : year;
        let prevMonthLastDay = new Date(prevYear, prevMonth + 1, 0).getDate();

        for (let i = startDayOfWeek - 1; i >= 0; i--) {
            calendar.push({
                day: prevMonthLastDay - i,
                isCurrentMonth: false,
                isPrevMonth: true,
                isNextMonth: false
            });
        }

        // Current month days
        for (let day = 1; day <= daysInMonth; day++) {
            calendar.push({
                day: day,
                isCurrentMonth: true,
                isPrevMonth: false,
                isNextMonth: false
            });
        }

        // Next month's leading days to fill the grid (42 cells = 6 weeks)
        let remainingCells = 42 - calendar.length;
        for (let day = 1; day <= remainingCells; day++) {
            calendar.push({
                day: day,
                isCurrentMonth: false,
                isPrevMonth: false,
                isNextMonth: true
            });
        }

        return calendar;
    }

    function previousMonth() {
        if (currentMonth === 0) {
            currentMonth = 11;
            currentYear--;
        } else {
            currentMonth--;
        }
        calendarData = generateCalendarData(currentMonth, currentYear);
    }

    function nextMonth() {
        if (currentMonth === 11) {
            currentMonth = 0;
            currentYear++;
        } else {
            currentMonth++;
        }
        calendarData = generateCalendarData(currentMonth, currentYear);
    }

    // Global overlay to close date selector when clicking anywhere
    MouseArea {
        anchors.fill: parent
        visible: root.showDateSelector
        onClicked: function (mouse) {
            console.log("Global overlay clicked - closing date selector");
            root.showDateSelector = false;
        }
        propagateComposedEvents: true
    }

    Layout.fillWidth: true
    Layout.preferredHeight: 340
    color: Config.colors.surfaceContainer
    radius: Config.shape.medium

    RowLayout {
        anchors.fill: parent
        anchors.margins: Config.spacing.medium
        spacing: Config.spacing.medium

        // Left side - Tab buttons
        ColumnLayout {
            Layout.preferredWidth: 60
            Layout.maximumWidth: 60
            spacing: Config.spacing.small

            Repeater {
                model: ["Calendar", "Notes"]

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    radius: Config.shape.small
                    color: index === root.bottomTab ? Config.colors.primaryContainer : "transparent"

                    MaterialText {
                        anchors.centerIn: parent
                        text: modelData
                        textStyle: "labelSmall"
                        colorRole: index === root.bottomTab ? "primaryContainerText" : "surfaceText"
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.bottomTab = index;
                            console.log("Bottom tab switched to:", modelData);
                        }
                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: Config.motion.duration.short3
                            easing.type: Config.motion.easing.standard
                        }
                    }
                }
            }

            // Spacer
            Item {
                Layout.fillHeight: true
            }
        }

        // Divider
        Rectangle {
            Layout.preferredWidth: 1
            Layout.fillHeight: true
            color: Config.colors.outlineVariant
            Layout.topMargin: Config.spacing.small
            Layout.bottomMargin: Config.spacing.small
        }

        // Right side - Tab content
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Loader {
                anchors.fill: parent
                sourceComponent: {
                    switch (root.bottomTab) {
                    case 0:
                        return calendarComponent;
                    case 1:
                        return notesComponent;
                    default:
                        return calendarComponent;
                    }
                }
            }
        }
    }

    // Bottom tab components
    Component {
        id: calendarComponent
        ColumnLayout {
            spacing: Config.spacing.small

            // Month/Year header
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true

                MaterialText {
                    text: "<"
                    textStyle: "bodyMedium"
                    colorRole: "surfaceText"
                    Layout.alignment: Qt.AlignVCenter

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.previousMonth()
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    radius: Config.shape.small
                    color: "transparent"

                    MaterialText {
                        anchors.centerIn: parent
                        text: new Date(root.currentYear, root.currentMonth).toLocaleString(Qt.locale(), "MMMM yyyy")
                        textStyle: "labelMedium"
                        colorRole: "surfaceText"
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.showDateSelector = !root.showDateSelector;
                        }
                    }

                    // Combined date selector overlay
                    Rectangle {
                        anchors.centerIn: parent
                        width: 200
                        height: 240
                        color: Config.colors.surfaceContainerHigh
                        radius: Config.shape.medium
                        border.width: 1
                        border.color: Config.colors.outlineVariant
                        visible: root.showDateSelector

                        MouseArea {
                            anchors.fill: parent
                            onClicked: function (mouse) {
                                console.log("Date selector clicked - staying open");
                                mouse.accepted = true;
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: Config.spacing.small
                            spacing: Config.spacing.small

                            // Year selector column
                            Column {
                                Layout.preferredWidth: 60
                                Layout.fillHeight: true
                                spacing: 2

                                MaterialText {
                                    text: "Year"
                                    textStyle: "labelSmall"
                                    colorRole: "surfaceVariantText"
                                    width: parent.width
                                    horizontalAlignment: Text.AlignHCenter
                                }

                                PathView {
                                    id: yearPathView
                                    width: parent.width
                                    height: parent.height - 20
                                    model: 101

                                    delegate: Rectangle {
                                        width: yearPathView.width
                                        height: 30
                                        radius: Config.shape.small
                                        property int yearValue: root.actualYear - 50 + modelData

                                        color: PathView.isCurrentItem ? Config.colors.primaryContainer : "transparent"

                                        MaterialText {
                                            anchors.centerIn: parent
                                            text: yearValue
                                            textStyle: "labelSmall"
                                            colorRole: PathView.isCurrentItem ? "primaryContainerText" : "surfaceText"
                                        }
                                    }

                                    path: Path {
                                        startX: yearPathView.width / 2
                                        startY: 0
                                        PathLine { x: yearPathView.width / 2; y: yearPathView.height }
                                    }

                                    pathItemCount: 7
                                    preferredHighlightBegin: 0.5
                                    preferredHighlightEnd: 0.5
                                    highlightRangeMode: PathView.StrictlyEnforceRange
                                    highlightMoveDuration: 200
                                    flickDeceleration: 1000
                                    maximumFlickVelocity: 1000

                                    Component.onCompleted: currentIndex = 50

                                    onCurrentIndexChanged: {
                                        const yearValue = root.actualYear - 50 + currentIndex
                                        root.currentYear = yearValue
                                        root.calendarData = root.generateCalendarData(root.currentMonth, root.currentYear)
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onWheel: function (wheel) {
                                            if (wheel.angleDelta.y > 0) {
                                                yearPathView.decrementCurrentIndex()
                                            } else if (wheel.angleDelta.y < 0) {
                                                yearPathView.incrementCurrentIndex()
                                            }
                                            wheel.accepted = true
                                        }
                                    }
                                }
                            }

                            // Divider
                            Rectangle {
                                Layout.preferredWidth: 1
                                Layout.fillHeight: true
                                color: Config.colors.outlineVariant
                            }

                            // Month selector column
                            Column {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                spacing: 2

                                MaterialText {
                                    text: "Month"
                                    textStyle: "labelSmall"
                                    colorRole: "surfaceVariantText"
                                    width: parent.width
                                    horizontalAlignment: Text.AlignHCenter
                                }

                                PathView {
                                    id: monthPathView
                                    width: parent.width
                                    height: parent.height - 20
                                    model: ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

                                    delegate: Rectangle {
                                        width: monthPathView.width
                                        height: 30
                                        radius: Config.shape.small

                                        color: PathView.isCurrentItem ? Config.colors.primaryContainer : "transparent"

                                        MaterialText {
                                            anchors.centerIn: parent
                                            text: modelData
                                            textStyle: "labelSmall"
                                            colorRole: PathView.isCurrentItem ? "primaryContainerText" : "surfaceText"
                                        }
                                    }

                                    path: Path {
                                        startX: monthPathView.width / 2
                                        startY: 0
                                        PathLine { x: monthPathView.width / 2; y: monthPathView.height }
                                    }

                                    pathItemCount: 7
                                    preferredHighlightBegin: 0.5
                                    preferredHighlightEnd: 0.5
                                    highlightRangeMode: PathView.StrictlyEnforceRange
                                    highlightMoveDuration: 200

                                    Component.onCompleted: currentIndex = root.currentMonth
                                    onVisibleChanged: currentIndex = root.currentMonth

                                    onCurrentIndexChanged: {
                                        root.currentMonth = currentIndex
                                        root.calendarData = root.generateCalendarData(root.currentMonth, root.currentYear)
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onWheel: function (wheel) {
                                            if (wheel.angleDelta.y > 0) {
                                                monthPathView.decrementCurrentIndex()
                                            } else if (wheel.angleDelta.y < 0 ) {
                                                monthPathView.incrementCurrentIndex()
                                            }
                                            wheel.accepted = true
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                MaterialText {
                    text: ">"
                    textStyle: "bodyMedium"
                    colorRole: "surfaceText"
                    Layout.alignment: Qt.AlignVCenter

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.nextMonth()
                    }
                }
            }

            // Days grid
            GridLayout {
                Layout.fillWidth: true
                columns: 7
                rowSpacing: 2
                columnSpacing: 2

                // Day headers
                Repeater {
                    model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
                    MaterialText {
                        text: modelData
                        textStyle: "labelSmall"
                        colorRole: "surfaceVariantText"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 14
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                // Calendar days
                Repeater {
                    model: root.calendarData
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredHeight: 18
                        radius: 3

                        property bool isToday: modelData.isCurrentMonth && modelData.day === parseInt(Qt.locale().toString(DateTime.clock.date, "dd"))

                        color: isToday ? Config.colors.primary : "transparent"

                        MaterialText {
                            anchors.centerIn: parent
                            text: modelData.day
                            textStyle: "labelLarge"
                            colorRole: {
                                if (isToday)
                                    return "primaryText";
                                if (!modelData.isCurrentMonth)
                                    return "surfaceVariantText";
                                return "surfaceText";
                            }
                            opacity: modelData.isCurrentMonth ? 1.0 : 0.5
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            enabled: root.showDateSelector === false
                            onClicked: {
                                console.log("Day clicked:", modelData.day, modelData.isCurrentMonth ? "current" : modelData.isPrevMonth ? "prev" : "next");
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: notesComponent
        Rectangle {
            color: Config.colors.surfaceContainerHigh
            radius: Config.shape.small

            MaterialText {
                anchors.centerIn: parent
                text: "Quick notes\n& reminders\n\nClick to add..."
                textStyle: "bodySmall"
                colorRole: "surfaceVariantText"
                horizontalAlignment: Text.AlignHCenter
                opacity: 0.7
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    console.log("Notes area clicked - TODO: Add note functionality");
                }
            }
        }
    }
}