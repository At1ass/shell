import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.src.ui.containers
import qs.src.ui.base
import qs.src.ui.feedback
import qs.src.core.config
import qs.src.core.services
import qs.src.features.dashboard.components


Item {
    id: root

    property int currentMonth: new Date().getMonth()
    property int currentYear: new Date().getFullYear()
    property date selectedDate: new Date()
    property date today: new Date()
    property var selectedDayEvents: CalendarService.dayEvents

    // Keyboard navigation
    property int focusedCellIndex: -1

    function moveFocusBy(delta) {
        if (focusedCellIndex < 0) _initFocusedCell()
        const newIndex = focusedCellIndex + delta
        if (newIndex >= 0 && newIndex < calendarDays.count) {
            focusedCellIndex = newIndex
        }
    }

    function selectFocused() {
        if (focusedCellIndex >= 0 && focusedCellIndex < calendarDays.count) {
            const item = calendarDays.get(focusedCellIndex)
            selectedDate = item.date
            CalendarService.loadEventsForDate(Qt.formatDate(item.date, "yyyy-MM-dd"))
        }
    }

    function goToPrevMonth() {
        if (currentMonth === 0) { currentMonth = 11; currentYear-- }
        else currentMonth--
        updateCalendar()
        _initFocusedCell()
    }

    function goToNextMonth() {
        if (currentMonth === 11) { currentMonth = 0; currentYear++ }
        else currentMonth++
        updateCalendar()
        _initFocusedCell()
    }

    function goToFirstDay() {
        for (let i = 0; i < calendarDays.count; i++) {
            if (calendarDays.get(i).isCurrentMonth) { focusedCellIndex = i; return }
        }
    }

    function goToLastDay() {
        for (let i = calendarDays.count - 1; i >= 0; i--) {
            if (calendarDays.get(i).isCurrentMonth) { focusedCellIndex = i; return }
        }
    }

    function openNewEvent() {
        eventDialog.openDialog(false, null, root.selectedDate)
    }

    function _initFocusedCell() {
        for (let i = 0; i < calendarDays.count; i++) {
            const item = calendarDays.get(i)
            if (item.isCurrentMonth && isSameDate(item.date, today)) {
                focusedCellIndex = i; return
            }
        }
        goToFirstDay()
    }

    ListModel {
        id: calendarDays
    }

    Connections {
        target: CalendarService
        function onDayEventsChanged() {
            root.selectedDayEvents = CalendarService.dayEvents
        }
        function onEventsChanged() {
            // Grid indicators updated via CalendarService.eventsByDate binding
        }
    }

    function generateCalendar() {
        calendarDays.clear()

        const firstDay = new Date(currentYear, currentMonth, 1)
        const lastDay = new Date(currentYear, currentMonth + 1, 0)
        const daysInMonth = lastDay.getDate()

        let firstDayOfWeek = firstDay.getDay()
        firstDayOfWeek = firstDayOfWeek === 0 ? 6 : firstDayOfWeek - 1

        const prevMonthLastDay = new Date(currentYear, currentMonth, 0).getDate()
        for (let i = firstDayOfWeek - 1; i >= 0; i--) {
            calendarDays.append({
                day: prevMonthLastDay - i,
                isCurrentMonth: false,
                date: new Date(currentYear, currentMonth - 1, prevMonthLastDay - i)
            })
        }

        for (let day = 1; day <= daysInMonth; day++) {
            calendarDays.append({
                day: day,
                isCurrentMonth: true,
                date: new Date(currentYear, currentMonth, day)
            })
        }

        const remainingCells = 42 - calendarDays.count
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

        // Load events for the entire grid range (6 weeks)
        const firstDate = calendarDays.get(0).date
        const lastDate = calendarDays.get(calendarDays.count - 1).date
        CalendarService.loadEventsForRange(firstDate, lastDate)

        CalendarService.loadEventsForDate(Qt.formatDate(selectedDate, "yyyy-MM-dd"))
    }

    function isSameDate(date1, date2) {
        return date1.getFullYear() === date2.getFullYear() &&
               date1.getMonth() === date2.getMonth() &&
               date1.getDate() === date2.getDate()
    }

    Component.onCompleted: {
        updateCalendar()
        _initFocusedCell()
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: Tokens.spacing.large
        spacing: Tokens.spacing.large

        // Left panel — month grid
        MaterialCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Qt.alpha(Theme.surfaceContainerHigh, 0.80)
            radius: Tokens.shape.large

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Tokens.spacing.large
                spacing: Tokens.spacing.medium

                // Month navigation
                RowLayout {
                    Layout.fillWidth: true

                    IconButton {
                        variant: "standard"
                        iconName: "chevron_left"
                        iconSize: Tokens.iconSize.large
                        onClicked: root.goToPrevMonth()
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
                        onClicked: root.goToNextMonth()
                    }
                }

                // Day headers
                GridLayout {
                    Layout.fillWidth: true
                    columns: 7
                    columnSpacing: 8
                    rowSpacing: 4
                    uniformCellWidths: true
                    uniformCellHeights: true

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

                    // Calendar cells
                    Repeater {
                        model: calendarDays

                        delegate: Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 44
                            radius: Tokens.shape.full

                            property bool isToday: root.isSameDate(model.date, root.today)
                            property bool isSelected: root.isSameDate(model.date, root.selectedDate)
                            property bool isFocused: index === root.focusedCellIndex
                            property string dateStr: Qt.formatDate(model.date, "yyyy-MM-dd")
                            property int eventCount: CalendarService.eventCountOnDate(dateStr)

                            color: {
                                if (isToday) return Theme.primary
                                if (isFocused && !isSelected) return Theme.tertiaryContainer
                                if (isSelected) return Theme.secondaryContainer
                                if (dayMouseArea.containsMouse) return Theme.surfaceContainerHighest
                                return "transparent"
                            }

                            border.width: (isFocused || (isSelected && !isToday)) ? 2 : 0
                            border.color: isFocused ? Theme.tertiary : Theme.primary

                            Behavior on color {
                                ColorAnimation { duration: Tokens.motion.duration.short4 }
                            }

                            Column {
                                anchors.centerIn: parent
                                spacing: 2

                                MaterialText {
                                    anchors.horizontalCenter: parent.horizontalCenter
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

                                // Event indicator dots
                                Row {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    spacing: 3
                                    visible: eventCount > 0

                                    Repeater {
                                        model: Math.min(eventCount, 3)

                                        Rectangle {
                                            width: 4
                                            height: 4
                                            radius: 2
                                            color: isToday ? Theme.onPrimary : Theme.primary
                                            opacity: model.isCurrentMonth ? 1.0 : 0.5
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                id: dayMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor

                                onClicked: {
                                    root.selectedDate = model.date
                                    root.focusedCellIndex = index
                                    CalendarService.loadEventsForDate(Qt.formatDate(model.date, "yyyy-MM-dd"))
                                }
                            }
                        }
                    }
                }
            }
        }

        // Right panel — day view timeline
        MaterialCard {
            Layout.preferredWidth: 320
            Layout.fillHeight: true
            color: Qt.alpha(Theme.surfaceContainerHigh, 0.80)
            radius: Tokens.shape.large

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Tokens.spacing.medium
                spacing: Tokens.spacing.small

                // Date header
                MaterialText {
                    text: Qt.formatDate(root.selectedDate, "dddd, MMMM d")
                    textStyle: "titleMedium"
                    colorRole: "onSurface"
                    font.weight: Font.Medium
                    Layout.fillWidth: true
                }

                // All-day events section
                Flow {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.extraSmall
                    visible: _allDayEvents.length > 0

                    property var _allDayEvents: root.selectedDayEvents.filter(ev => ev.allDay)

                    Repeater {
                        model: parent._allDayEvents

                        Rectangle {
                            width: allDayLabel.implicitWidth + Tokens.spacing.medium * 2
                            height: 28
                            radius: Tokens.shape.small
                            color: Theme.tertiaryContainer

                            MaterialText {
                                id: allDayLabel
                                anchors.centerIn: parent
                                text: modelData.title
                                textStyle: "labelMedium"
                                colorRole: "onTertiaryContainer"
                            }
                        }
                    }
                }

                Divider {
                    Layout.fillWidth: true
                    visible: root.selectedDayEvents.length > 0
                }

                // Timeline scroll view
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Flickable {
                        id: timelineFlickable
                        anchors.fill: parent
                        contentHeight: timelineColumn.height
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        ScrollBar.vertical: ScrollBar {
                            active: timelineFlickable.moving || hovered
                            policy: ScrollBar.AsNeeded
                        }

                        Component.onCompleted: {
                            // Auto-scroll to current hour
                            if (root.isSameDate(root.selectedDate, root.today)) {
                                const hour = new Date().getHours()
                                const targetY = Math.max(0, (hour - 1) * AppConfig.calendarDayViewHourHeight)
                                contentY = Math.min(targetY, contentHeight - height)
                            }
                        }

                        Item {
                            id: timelineColumn
                            width: timelineFlickable.width
                            height: 24 * AppConfig.calendarDayViewHourHeight

                            // Hour lines and labels
                            Repeater {
                                model: 24

                                Item {
                                    x: 0
                                    y: index * AppConfig.calendarDayViewHourHeight
                                    width: timelineColumn.width
                                    height: AppConfig.calendarDayViewHourHeight

                                    MaterialText {
                                        anchors.left: parent.left
                                        anchors.top: parent.top
                                        anchors.topMargin: -6
                                        text: (index < 10 ? "0" : "") + index + ":00"
                                        textStyle: "labelSmall"
                                        colorRole: "onSurfaceVariant"
                                        width: 36
                                    }

                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 40
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        height: 1
                                        color: Theme.outlineVariant
                                        opacity: 0.5
                                    }
                                }
                            }

                            // Current time indicator
                            Rectangle {
                                visible: root.isSameDate(root.selectedDate, root.today)
                                x: 38
                                width: timelineColumn.width - 38
                                height: 2
                                radius: 1
                                color: Theme.error
                                y: {
                                    const now = new Date()
                                    return (now.getHours() + now.getMinutes() / 60) * AppConfig.calendarDayViewHourHeight
                                }

                                // Red dot at the start of the line
                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: -4
                                    width: 8
                                    height: 8
                                    radius: 4
                                    color: Theme.error
                                }

                                Timer {
                                    interval: 60000
                                    repeat: true
                                    running: visible
                                    onTriggered: parent.y = Qt.binding(() => {
                                        const now = new Date()
                                        return (now.getHours() + now.getMinutes() / 60) * AppConfig.calendarDayViewHourHeight
                                    })
                                }
                            }

                            // Event cards
                            Repeater {
                                model: {
                                    return root.selectedDayEvents.filter(ev => !ev.allDay && ev.startTime)
                                }

                                Rectangle {
                                    readonly property var ev: modelData
                                    readonly property var startParts: ev.startTime.split(":")
                                    readonly property real startHour: parseInt(startParts[0]) + parseInt(startParts[1]) / 60
                                    readonly property var endParts: (ev.endTime || "").split(":")
                                    readonly property real endHour: endParts.length >= 2
                                        ? parseInt(endParts[0]) + parseInt(endParts[1]) / 60
                                        : startHour + 1
                                    readonly property real durationHours: Math.max(0.5, endHour - startHour)

                                    x: 44
                                    y: startHour * AppConfig.calendarDayViewHourHeight
                                    width: timelineColumn.width - 48
                                    height: Math.max(30, durationHours * AppConfig.calendarDayViewHourHeight - 2)
                                    radius: Tokens.shape.small
                                    color: Theme.primaryContainer

                                    // Left accent bar
                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.top: parent.top
                                        anchors.bottom: parent.bottom
                                        width: 4
                                        radius: 2
                                        color: Theme.primary
                                    }

                                    // Hover state
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: parent.radius
                                        color: Theme.onSurface
                                        opacity: eventCardMouse.containsMouse ? Tokens.stateLayer.hoverOpacity : 0
                                    }

                                    Column {
                                        anchors.fill: parent
                                        anchors.leftMargin: Tokens.spacing.small + 4
                                        anchors.rightMargin: Tokens.spacing.small
                                        anchors.topMargin: Tokens.spacing.extraSmall
                                        anchors.bottomMargin: Tokens.spacing.extraSmall
                                        spacing: 1
                                        clip: true

                                        MaterialText {
                                            text: ev.title
                                            textStyle: "labelMedium"
                                            colorRole: "onPrimaryContainer"
                                            elide: Text.ElideRight
                                            width: parent.width
                                            font.weight: Font.Medium
                                        }

                                        MaterialText {
                                            text: ev.startTime + (ev.endTime ? " – " + ev.endTime : "")
                                            textStyle: "labelSmall"
                                            colorRole: "onPrimaryContainer"
                                            opacity: 0.8
                                            visible: parent.height > 28
                                        }

                                        MaterialText {
                                            text: ev.location || ""
                                            textStyle: "labelSmall"
                                            colorRole: "onPrimaryContainer"
                                            opacity: 0.6
                                            visible: text.length > 0 && parent.height > 44
                                            elide: Text.ElideRight
                                            width: parent.width
                                        }
                                    }

                                    MouseArea {
                                        id: eventCardMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            eventDialog.openDialog(true, ev, root.selectedDate)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Empty state (overlays timeline when no events)
                    EmptyState {
                        anchors.centerIn: parent
                        visible: root.selectedDayEvents.length === 0
                        iconName: "event_busy"
                        title: "No events"
                        subtitle: "Press N to add an event"
                    }
                }

                // Add event button
                MaterialButton {
                    Layout.fillWidth: true
                    text: "Add Event"
                    variant: "tonal"
                    onClicked: eventDialog.openDialog(false, null, root.selectedDate)
                }
            }
        }
    }

    EventDialog {
        id: eventDialog
        anchors.fill: parent

        onEventSaved: (title, startTime, endTime, calendar, description, location, categories, recurrence, until) => {
            if (isEditMode && eventData && eventData.uid) {
                // Delete old + create new (khal has no programmatic edit)
                CalendarService.deleteEvent(eventData.uid, eventData.calendar)
            }
            CalendarService.addEvent(
                calendar || CalendarService.calendars[0] || "",
                Qt.formatDate(root.selectedDate, "yyyy-MM-dd"),
                startTime,
                endTime,
                title,
                description,
                location,
                categories,
                recurrence,
                until
            )
        }

        onEventDeleted: (uid, calendar) => {
            CalendarService.deleteEvent(uid, calendar)
        }
    }
}
