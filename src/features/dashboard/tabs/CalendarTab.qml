import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Calendar
import qs.src.ui.containers
import qs.src.ui.base
import qs.src.ui.feedback
import qs.src.core.config
import qs.src.features.dashboard.components


Item {
    id: root

    property int currentMonth: new Date().getMonth()
    property int currentYear: new Date().getFullYear()
    property date selectedDate: new Date()
    property date today: new Date()
    property var selectedDayEvents: CalendarBackend.dayEvents

    // Day-header labels rotated to start from AppConfig.calendarFirstDayOfWeek.
    property var _dayNames: {
        const all = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        const start = AppConfig.calendarFirstDayOfWeek
        return all.slice(start).concat(all.slice(0, start))
    }

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
            CalendarBackend.loadEventsForDate(item.date)
        }
    }

    function goToPrevMonth() {
        if (currentMonth === 0) { currentMonth = 11; currentYear-- }
        else currentMonth--
        updateCalendar()
    }

    function goToNextMonth() {
        if (currentMonth === 11) { currentMonth = 0; currentYear++ }
        else currentMonth++
        updateCalendar()
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
        target: CalendarBackend
        function onDayEventsChanged() {
            root.selectedDayEvents = CalendarBackend.dayEvents
        }
    }

    function generateCalendar() {
        calendarDays.clear()

        const firstDay = new Date(currentYear, currentMonth, 1)
        const lastDay = new Date(currentYear, currentMonth + 1, 0)
        const daysInMonth = lastDay.getDate()

        // Offset of the first cell from the configured first weekday.
        // JS getDay(): 0=Sunday..6=Saturday. We want the column index of the
        // 1st of the month under a week starting at AppConfig.calendarFirstDayOfWeek.
        const offset = (firstDay.getDay() - AppConfig.calendarFirstDayOfWeek + 7) % 7

        const prevMonthLastDay = new Date(currentYear, currentMonth, 0).getDate()
        for (let i = offset - 1; i >= 0; i--) {
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
        _initFocusedCell()

        // Sync selectedDate with focused cell so the day pane follows
        // month navigation (lands on today if visible, else day 1).
        if (focusedCellIndex >= 0 && focusedCellIndex < calendarDays.count) {
            selectedDate = calendarDays.get(focusedCellIndex).date
        }

        const firstDate = calendarDays.get(0).date
        const lastDate = calendarDays.get(calendarDays.count - 1).date
        CalendarBackend.loadEventsForRange(firstDate, lastDate)
        CalendarBackend.loadEventsForDate(selectedDate)
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
                        model: root._dayNames
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
                            // Reading eventsByDate makes this binding reactive
                            property var dayList: CalendarBackend.eventsByDate[Qt.formatDate(model.date, "yyyy-MM-dd")] || []
                            property int eventCount: dayList.length

                            // Today wins fill; selection layers an outline on top of today;
                            // focus always shows as a tertiary outline (overrides selection outline).
                            color: {
                                if (isToday) return Theme.primary
                                if (isSelected) return Theme.secondaryContainer
                                if (dayMouseArea.containsMouse) return Theme.surfaceContainerHighest
                                return "transparent"
                            }

                            border.width: isFocused ? 2 : (isSelected && isToday ? 2 : 0)
                            border.color: isFocused ? Theme.tertiary : Theme.onPrimary

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
                                        if (isSelected) return "onSecondaryContainer"
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
                                            color: isToday ? Theme.onPrimary
                                                : isSelected ? Theme.onSecondaryContainer
                                                : Theme.primary
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
                                    CalendarBackend.loadEventsForDate(model.date)
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
                    id: flow
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.extraSmall
                    visible: _allDayEvents.length > 0

                    property var _allDayEvents: root.selectedDayEvents.filter(ev => ev.allDay)

                    Repeater {
                        model: parent._allDayEvents

                        Rectangle {
                            property int maxWidth: flow.width

                            width: Math.min(
                                allDayLabel.implicitWidth + Tokens.spacing.medium * 2,
                                maxWidth
                            )
                            height: allDayLabel.implicitHeight + Tokens.spacing.extraSmall * 2
                            radius: Tokens.shape.small
                            color: Theme.tertiaryContainer

                            MaterialText {
                                id: allDayLabel
                                anchors.centerIn: parent
                                text: modelData.title
                                textStyle: "labelMedium"
                                colorRole: "onTertiaryContainer"
                                wrapMode: Text.WordWrap
                                width: parent.width - Tokens.spacing.medium * 2
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: eventDialog.openDialog(true, modelData, root.selectedDate)
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

                        // Auto-scroll to current hour once height is known.
                        // Component.onCompleted runs while height is still 0 in
                        // a lazy-loaded StackLayout/Loader chain.
                        property bool _didAutoScroll: false
                        onHeightChanged: {
                            if (_didAutoScroll || height <= 0) return
                            if (!root.isSameDate(root.selectedDate, root.today)) {
                                _didAutoScroll = true
                                return
                            }
                            const hour = new Date().getHours()
                            const targetY = Math.max(0, (hour - 1) * AppConfig.calendarDayViewHourHeight)
                            contentY = Math.min(targetY, Math.max(0, contentHeight - height))
                            _didAutoScroll = true
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
                                    return root.selectedDayEvents.filter(ev => !ev.allDay && ev.start)
                                }

                                Rectangle {
                                    readonly property var ev: modelData
                                    readonly property real startHour: ev.start
                                        ? (ev.start.getHours() + ev.start.getMinutes() / 60)
                                        : 0
                                    readonly property real endHour: ev.end
                                        ? (ev.end.getHours() + ev.end.getMinutes() / 60)
                                        : startHour + 1
                                    readonly property real durationHours: Math.max(0.5, endHour - startHour)

                                    x: 44
                                    y: startHour * AppConfig.calendarDayViewHourHeight
                                    width: timelineColumn.width - 48
                                    height: Math.max(30, durationHours * AppConfig.calendarDayViewHourHeight - 2)
                                    radius: Tokens.shape.small
                                    color: Theme.primaryContainer

                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.top: parent.top
                                        anchors.bottom: parent.bottom
                                        width: 4
                                        radius: 2
                                        color: Theme.primary
                                    }

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
                                            text: Qt.formatTime(ev.start, "HH:mm")
                                                + (ev.end ? " – " + Qt.formatTime(ev.end, "HH:mm") : "")
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
                                        onClicked: eventDialog.openDialog(true, ev, root.selectedDate)
                                    }
                                }
                            }
                        }
                    }

                    EmptyState {
                        anchors.centerIn: parent
                        visible: root.selectedDayEvents.length === 0
                        iconName: "event_busy"
                        title: "No events"
                        subtitle: "Press N to add an event"
                    }
                }

                MaterialButton {
                    Layout.fillWidth: true
                    text: "Add Event"
                    variant: "tonal"
                    enabled: CalendarBackend.calendars.length > 0
                    ToolTip.visible: hovered && !enabled
                    ToolTip.text: "No calendars configured. Add one in ~/.config/khal/config or ensure ~/.local/share/khal/calendars/<name>/ exists."
                    onClicked: eventDialog.openDialog(false, null, root.selectedDate)
                }
            }
        }
    }

    EventDialog {
        id: eventDialog
        anchors.fill: parent

        onEventSaved: (fields) => {
            const isEdit = isEditMode && eventData && eventData.uid
            if (isEdit && eventData.isRecurringMaster) {
                // Ask user: this occurrence or whole series
                recurrenceChoice.askEdit(eventData, fields)
            } else if (isEdit) {
                CalendarBackend.editEvent(eventData.uid, fields, "all")
            } else {
                CalendarBackend.addEvent(fields)
            }
        }

        onEventDeleted: (uid, isRecurring) => {
            if (isRecurring) {
                recurrenceChoice.askDelete(eventData)
            } else {
                CalendarBackend.deleteEvent(uid, "all")
            }
        }
    }

    RecurrenceEditChoice {
        id: recurrenceChoice
        anchors.fill: parent

        onChoiceMade: (mode, intent, ev, fields) => {
            // mode: "this" | "all"; intent: "edit" | "delete"
            if (intent === "edit") {
                CalendarBackend.editEvent(ev.uid, fields, mode, ev.start)
            } else {
                CalendarBackend.deleteEvent(ev.uid, mode, ev.start)
            }
        }
    }
}
