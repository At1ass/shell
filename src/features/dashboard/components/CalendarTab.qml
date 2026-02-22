import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.src.ui.containers
import qs.src.ui.base
import qs.src.ui.feedback
import qs.src.core.config
import qs.src.core.services


Item {
    id: root

    property int currentMonth: new Date().getMonth()
    property int currentYear: new Date().getFullYear()
    property date selectedDate: new Date()
    property date today: new Date()
    property var selectedDayEvents: CalendarService.todayEvents

    ListModel {
        id: calendarDays
    }

    Connections {
        target: CalendarService
        function onEventsChanged() {
            // Update selected day events when calendar events change
            root.selectedDayEvents = CalendarService.todayEvents
        }
    }


    function generateCalendar() {
        calendarDays.clear()

        const firstDay = new Date(currentYear, currentMonth, 1)
        const lastDay = new Date(currentYear, currentMonth + 1, 0)
        const daysInMonth = lastDay.getDate()

        // Get day of week (0=Sunday, 1=Monday, etc)
        let firstDayOfWeek = firstDay.getDay()
        // Convert to Monday=0 format
        firstDayOfWeek = firstDayOfWeek === 0 ? 6 : firstDayOfWeek - 1

        // Previous month days
        const prevMonthLastDay = new Date(currentYear, currentMonth, 0).getDate()
        for (let i = firstDayOfWeek - 1; i >= 0; i--) {
            calendarDays.append({
                day: prevMonthLastDay - i,
                isCurrentMonth: false,
                date: new Date(currentYear, currentMonth - 1, prevMonthLastDay - i)
            })
        }

        // Current month days
        for (let day = 1; day <= daysInMonth; day++) {
            calendarDays.append({
                day: day,
                isCurrentMonth: true,
                date: new Date(currentYear, currentMonth, day)
            })
        }

        // Next month days to fill grid
        const remainingCells = 42 - calendarDays.count // 6 rows × 7 days
        for (let day = 1; day <= remainingCells; day++) {
            calendarDays.append({
                day: day,
                isCurrentMonth: false,
                date: new Date(currentYear, currentMonth + 1, day)
            })
        }
    }

    function updateCalendar() {
        const date = new Date(currentYear, currentMonth, 1)
        monthText.text = Qt.formatDate(date, "MMMM yyyy")
        generateCalendar()
        CalendarService.loadEventsByDate(Qt.formatDate(selectedDate, "yyyy-MM-dd"))
    }

    function isSameDate(date1, date2) {
        return date1.getFullYear() === date2.getFullYear() &&
               date1.getMonth() === date2.getMonth() &&
               date1.getDate() === date2.getDate()
    }

    Component.onCompleted: updateCalendar()

    RowLayout {
        anchors.fill: parent
        anchors.margins: Tokens.spacing.large
        spacing: Tokens.spacing.large

        // Календарь (основная часть)
        MaterialCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Theme.surfaceContainerHigh
            radius: Tokens.shape.large

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Tokens.spacing.large
                spacing: Tokens.spacing.medium

                // Навигация по месяцам
                RowLayout {
                    Layout.fillWidth: true

                    IconButton {
                        variant: "standard"
                        iconName: "chevron_left"
                        iconSize: Tokens.iconSize.large
                        onClicked: {
                            if (root.currentMonth === 0) {
                                root.currentMonth = 11
                                root.currentYear--
                            } else {
                                root.currentMonth--
                            }
                            root.updateCalendar()
                        }
                    }

                    Item { Layout.fillWidth: true }

                    MaterialText {
                        id: monthText
                        text: "June 2025"
                        textStyle: "titleLarge"
                        colorRole: "onSurface"
                        font.weight: Font.Medium
                    }

                    Item { Layout.fillWidth: true }

                    IconButton {
                        variant: "standard"
                        iconName: "chevron_right"
                        iconSize: Tokens.iconSize.large
                        onClicked: {
                            if (root.currentMonth === 11) {
                                root.currentMonth = 0
                                root.currentYear++
                            } else {
                                root.currentMonth++
                            }
                            root.updateCalendar()
                        }
                    }
                }

                // Дни недели
                GridLayout {
                    Layout.fillWidth: true
                    columns: 7
                    columnSpacing: 8
                    rowSpacing: 8

                    Repeater {
                        model: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
                        MaterialText {
                            text: modelData
                            textStyle: "labelSmall"
                            colorRole: "onSurfaceVariant"
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            font.weight: Font.Medium
                        }
                    }

                    // Даты месяца
                    Repeater {
                        model: calendarDays

                        delegate: Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 40
                            radius: 20

                            property bool isToday: root.isSameDate(model.date, root.today)
                            property bool isSelected: root.isSameDate(model.date, root.selectedDate)

                            color: {
                                if (isToday) return Theme.primary
                                if (isSelected) return Theme.secondaryContainer
                                if (dayMouseArea.containsMouse) return Theme.surfaceContainerHighest
                                return "transparent"
                            }

                            border.width: isSelected && !isToday ? 2 : 0
                            border.color: Theme.primary

                            Behavior on color {
                                ColorAnimation { duration: Tokens.motion.duration.short4 }
                            }

                            MaterialText {
                                anchors.centerIn: parent
                                text: model.day
                                textStyle: "bodyMedium"
                                colorRole: {
                                    if (isToday) return "onPrimary"
                                    if (!model.isCurrentMonth) return "onSurfaceVariant"
                                    return "onSurface"
                                }
                                font.weight: isToday || isSelected ? Font.Bold : Font.Normal
                                opacity: model.isCurrentMonth ? 1.0 : 0.5
                            }

                            MouseArea {
                                id: dayMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor

                                onClicked: {
                                    root.selectedDate = model.date
                                    CalendarService.loadEventsByDate(Qt.formatDate(model.date, "yyyy-MM-dd"))
                                }
                            }
                        }
                    }
                }
            }
        }

        // Заметки (боковая панель)
        MaterialCard {
            Layout.preferredWidth: 280
            Layout.fillHeight: true
            color: Theme.surfaceContainerHigh
            radius: Tokens.shape.large

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Tokens.spacing.medium
                spacing: Tokens.spacing.medium

                MaterialText {
                    text: Qt.formatDate(root.selectedDate, "MMMM d, yyyy")
                    textStyle: "titleMedium"
                    colorRole: "onSurface"
                    font.weight: Font.Medium
                }

                // Список событий с прокруткой
                ScrollableList {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: Tokens.spacing.small

                    Repeater {
                            model: ScriptModel {
                                values: root.selectedDayEvents
                            }

                            delegate: ListItem {
                                Layout.fillWidth: true
                                radius: Tokens.shape.medium
                                color: Theme.surfaceContainerHighest

                                headline: modelData.title
                                supportingText: modelData.time

                                leadingContent: Rectangle {
                                    width: 4
                                    height: 48
                                    radius: 2
                                    color: {
                                        if (modelData.color === 'primary') return Theme.primary
                                        if (modelData.color === 'secondary') return Theme.secondary
                                        if (modelData.color === 'tertiary') return Theme.tertiary
                                        return Theme.primary
                                    }
                                }

                                onClicked: {
                                    eventDialog.openDialog(true, modelData, root.selectedDate)
                                }
                            }
                        }

                    // Empty state
                    EmptyState {
                        visible: root.selectedDayEvents.length === 0
                        Layout.fillWidth: true
                        Layout.preferredHeight: 200

                        iconName: "event_busy"
                        title: "No events on this day"
                        subtitle: "Add an event to get started"
                    }
                }

                // Кнопка добавления события
                Rectangle {
                    Layout.fillWidth: true
                    height: 48
                    radius: Tokens.shape.medium
                    color: addButtonMouseArea.containsMouse ? Theme.primary : Theme.primaryContainer

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: Tokens.spacing.small

                        MaterialIcon {
                            iconName: "add"
                            fontSize: Tokens.typography.titleMedium.size
                            iconColor: addButtonMouseArea.containsMouse ? Theme.onPrimary : Theme.onPrimaryContainer
                            backgroundColor: "transparent"
                        }

                        MaterialText {
                            text: "Add Event"
                            textStyle: "labelLarge"
                            colorRole: addButtonMouseArea.containsMouse ? "onPrimary" : "onPrimaryContainer"
                        }
                    }

                    Behavior on color {
                        ColorAnimation { duration: Tokens.motion.duration.short4 }
                    }

                    MouseArea {
                        id: addButtonMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onClicked: {
                            eventDialog.openDialog(false, null, root.selectedDate)
                        }
                    }
                }
            }
        }
    }

    // Event Dialog
    EventDialog {
        id: eventDialog
        anchors.fill: parent

        onEventSaved: (title, startTime, endTime, color) => {
            if (isEditMode && eventData) {
                CalendarService.updateEvent(
                    eventData.id,
                    Qt.formatDate(root.selectedDate, "yyyy-MM-dd"),
                    startTime,
                    endTime,
                    title,
                    "",
                    color
                )
            } else {
                CalendarService.addEvent(
                    Qt.formatDate(root.selectedDate, "yyyy-MM-dd"),
                    startTime,
                    endTime,
                    title,
                    "",
                    color
                )
            }
        }

        onEventDeleted: (eventId) => {
            CalendarService.deleteEvent(eventId)
        }
    }
}
