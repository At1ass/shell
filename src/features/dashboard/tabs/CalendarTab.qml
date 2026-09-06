pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Calendar
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

    // Midnight-reactive: SystemClock ticks each minute but the derived
    // date VALUE only changes at midnight, so onTodayChanged fires exactly
    // once per day (a tab left open no longer highlights yesterday).
    readonly property date today: new Date(DateTime.clock.date.getFullYear(),
                                           DateTime.clock.date.getMonth(),
                                           DateTime.clock.date.getDate())
    onTodayChanged: updateCalendar()

    // Modal state for DashboardContent's key routing: while a dialog is up,
    // dashboard-level keys (Escape/tab digits) must not fire.
    readonly property bool modalOpen: eventDialog.visible || recurrenceChoice.visible
    function closeTopModal() {
        if (recurrenceChoice.visible) recurrenceChoice.close()
        else if (eventDialog.visible) eventDialog.requestClose()
    }
    property var selectedDayEvents: CalendarBackend.dayEvents

    // Explicit property rather than calling isSameDate() inside a binding.
    // QML cannot see through a function call to know what it depends on, and
    // the "current time" indicator's `visible` read both selectedDate and
    // today while onTodayChanged -> updateCalendar() writes selectedDate —
    // which QML reported as a binding loop on `visible`.
    readonly property bool todayIsSelected:
        selectedDate.getFullYear() === today.getFullYear()
        && selectedDate.getMonth() === today.getMonth()
        && selectedDate.getDate() === today.getDate()

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
        if (CalendarBackend.calendars.length === 0) return
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
        target: AppConfig
        function onCalendarFirstDayOfWeekChanged() { root.updateCalendar() }
    }

    function generateCalendar() {
        // The grid is ALWAYS 42 cells, so the model is updated in place
        // instead of cleared and refilled. clear() + append() destroys and
        // recreates every delegate, and the QML profiler measured the cost:
        // one open of this tab rebuilt the grid 4 times and created 1382
        // objects, and every month-arrow click paid for 42 more delegate
        // tear-downs. set() keeps the delegates alive and just changes data.
        const firstDay = new Date(currentYear, currentMonth, 1)
        const lastDay = new Date(currentYear, currentMonth + 1, 0)
        const daysInMonth = lastDay.getDate()

        // Offset of the first cell from the configured first weekday.
        // JS getDay(): 0=Sunday..6=Saturday. We want the column index of the
        // 1st of the month under a week starting at AppConfig.calendarFirstDayOfWeek.
        const offset = (firstDay.getDay() - AppConfig.calendarFirstDayOfWeek + 7) % 7
        const prevMonthLastDay = new Date(currentYear, currentMonth, 0).getDate()

        const cells = []
        for (let i = offset - 1; i >= 0; i--) {
            cells.push({ day: prevMonthLastDay - i, isCurrentMonth: false,
                         date: new Date(currentYear, currentMonth - 1, prevMonthLastDay - i) })
        }
        for (let day = 1; day <= daysInMonth; day++) {
            cells.push({ day: day, isCurrentMonth: true,
                         date: new Date(currentYear, currentMonth, day) })
        }
        for (let day = 1; cells.length < 42; day++) {
            cells.push({ day: day, isCurrentMonth: false,
                         date: new Date(currentYear, currentMonth + 1, day) })
        }

        for (let i = 0; i < cells.length; i++) {
            if (i < calendarDays.count) calendarDays.set(i, cells[i])
            else calendarDays.append(cells[i])
        }
        while (calendarDays.count > cells.length) calendarDays.remove(calendarDays.count - 1)
    }

    function updateCalendar() {
        const date = new Date(currentYear, currentMonth, 1)
        monthText.text = Qt.formatDate(date, "MMMM yyyy")
        generateCalendar()
        _initFocusedCell()

        // Sync selectedDate with focused cell so the day pane follows
        // month navigation (lands on today if visible, else day 1).
        if (focusedCellIndex >= 0 && focusedCellIndex < calendarDays.count) {
            // Only on a real change: rewriting the same date still emits
            // selectedDateChanged and re-entered the chain above.
            const d = calendarDays.get(focusedCellIndex).date
            if (!isSameDate(d, selectedDate)) selectedDate = d
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
                            id: dayNameLabel
                            required property string modelData

                            text: dayNameLabel.modelData
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
                            id: dayCell

                            // Under `pragma ComponentBehavior: Bound` a delegate
                            // must declare what it takes from the model rather
                            // than inheriting it from the enclosing context.
                            required property var model
                            required property int index

                            Layout.fillWidth: true
                            Layout.preferredHeight: 44
                            radius: Tokens.shape.pill

                            property bool isToday: root.isSameDate(dayCell.model.date, root.today)
                            property bool isSelected: root.isSameDate(dayCell.model.date, root.selectedDate)
                            property bool isFocused: dayCell.index === root.focusedCellIndex
                            // The dot Repeater's model is an INT — inside it,
                            // `model.<role>` is shadowed and reads undefined.
                            readonly property bool inCurrentMonth: dayCell.model.isCurrentMonth
                            // Reading eventsByDate makes this binding reactive
                            property var dayList: CalendarBackend.eventsByDate[Qt.formatDate(dayCell.model.date, "yyyy-MM-dd")] || []
                            property int eventCount: dayCell.dayList.length

                            // Today wins fill; selection layers an outline on top of today;
                            // focus always shows as a tertiary outline (overrides selection outline).
                            color: {
                                if (dayCell.isToday) return Theme.primary
                                if (dayCell.isSelected) return Theme.secondaryContainer
                                if (dayMouseArea.containsMouse) return Theme.surfaceContainerHighest
                                return "transparent"
                            }

                            border.width: dayCell.isFocused ? 2 : (dayCell.isSelected && dayCell.isToday ? 2 : 0)
                            border.color: dayCell.isFocused ? Theme.tertiary : Theme.onPrimary

                            Behavior on color {
                                MotionColorAnimation {
                                    duration: Tokens.motion.duration.short4
                                    curve: "standard"
                                }
                            }

                            Column {
                                anchors.centerIn: parent
                                spacing: 2

                                MaterialText {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: dayCell.model.day
                                    textStyle: "bodyMedium"
                                    colorRole: {
                                        if (dayCell.isToday) return "onPrimary"
                                        if (dayCell.isSelected) return "onSecondaryContainer"
                                        if (!dayCell.inCurrentMonth) return "onSurfaceVariant"
                                        return "onSurface"
                                    }
                                    font.weight: dayCell.isToday || dayCell.isSelected ? Font.Bold : Font.Normal
                                    opacity: dayCell.inCurrentMonth ? 1.0 : 0.5
                                }

                                // Event indicator dots
                                Row {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    spacing: 3
                                    visible: dayCell.eventCount > 0

                                    Repeater {
                                        model: Math.min(dayCell.eventCount, 3)

                                        Rectangle {
                                            width: 4
                                            height: 4
                                            radius: Tokens.shape.full
                                            color: dayCell.isToday ? Theme.onPrimary
                                                : dayCell.isSelected ? Theme.onSecondaryContainer
                                                : Theme.primary
                                            opacity: dayCell.inCurrentMonth ? 1.0 : 0.5
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
                                    root.selectedDate = dayCell.model.date
                                    root.focusedCellIndex = dayCell.index
                                    CalendarBackend.loadEventsForDate(dayCell.model.date)
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
                            id: allDayChip
                            required property var modelData

                            property int maxWidth: flow.width

                            width: Math.min(
                                allDayLabel.implicitWidth + Tokens.spacing.medium * 2,
                                allDayChip.maxWidth
                            )
                            height: allDayLabel.implicitHeight + Tokens.spacing.extraSmall * 2
                            radius: Tokens.shape.small
                            color: Theme.tertiaryContainer

                            MaterialText {
                                id: allDayLabel
                                anchors.centerIn: parent
                                text: allDayChip.modelData.title
                                textStyle: "labelMedium"
                                colorRole: "onTertiaryContainer"
                                wrapMode: Text.WordWrap
                                width: parent.width - Tokens.spacing.medium * 2
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: eventDialog.openDialog(true, allDayChip.modelData, root.selectedDate)
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
                                    id: hourRow
                                    required property int index

                                    x: 0
                                    y: hourRow.index * AppConfig.calendarDayViewHourHeight
                                    width: timelineColumn.width
                                    height: AppConfig.calendarDayViewHourHeight

                                    MaterialText {
                                        anchors.left: parent.left
                                        anchors.top: parent.top
                                        anchors.topMargin: -6
                                        text: (hourRow.index < 10 ? "0" : "") + hourRow.index + ":00"
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

                            // Current time indicator. DateTime.clock ticks
                            // per minute, so `y` is a plain reactive binding —
                            // no timer needed (the old one also ran while the
                            // line was hidden: Timer has no `visible`, so
                            // `running: visible` bound to the TAB's).
                            Rectangle {
                                visible: root.todayIsSelected
                                x: 38
                                width: timelineColumn.width - 38
                                height: 2
                                radius: Tokens.shape.full
                                color: Theme.error
                                y: (DateTime.clock.date.getHours()
                                    + DateTime.clock.date.getMinutes() / 60)
                                   * AppConfig.calendarDayViewHourHeight

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: -4
                                    width: 8
                                    height: 8
                                    radius: Tokens.shape.full
                                    color: Theme.error
                                }
                            }

                            // Event cards. Hours are clamped to the VIEWED
                            // day (multi-day events drew at their start-day
                            // clock position on continuation days), and
                            // overlapping events are laid out into columns —
                            // parallel meetings used to fully occlude each
                            // other, making the covered one unclickable.
                            Repeater {
                                model: {
                                    const dayStart = new Date(root.selectedDate)
                                    dayStart.setHours(0, 0, 0, 0)
                                    const dayEnd = new Date(dayStart)
                                    dayEnd.setDate(dayEnd.getDate() + 1)

                                    const items = root.selectedDayEvents
                                        .filter(ev => !ev.allDay && ev.start)
                                        .map(ev => {
                                            const s = ev.start < dayStart ? 0
                                                : ev.start.getHours() + ev.start.getMinutes() / 60
                                            let e
                                            if (!ev.end) e = s + 1
                                            else if (ev.end >= dayEnd) e = 24
                                            else e = ev.end.getHours() + ev.end.getMinutes() / 60
                                            if (e <= s) e = s + 0.5
                                            return { ev: ev, s: s, e: e, col: 0, cols: 1 }
                                        })
                                        .sort((a, b) => (a.s - b.s) || (b.e - a.e))

                                    // Greedy column assignment inside overlap clusters.
                                    let cluster = []
                                    let clusterEnd = -1
                                    const flush = () => {
                                        const n = Math.max(...cluster.map(i => i.col)) + 1
                                        for (const i of cluster) i.cols = n
                                        cluster = []
                                        clusterEnd = -1
                                    }
                                    for (const it of items) {
                                        if (cluster.length > 0 && it.s >= clusterEnd) flush()
                                        const used = cluster.filter(c => c.e > it.s).map(c => c.col)
                                        let col = 0
                                        while (used.indexOf(col) !== -1) col++
                                        it.col = col
                                        cluster.push(it)
                                        clusterEnd = Math.max(clusterEnd, it.e)
                                    }
                                    if (cluster.length > 0) flush()
                                    return items
                                }

                                Rectangle {
                                    readonly property var ev: modelData.ev
                                    readonly property real startHour: modelData.s
                                    readonly property real endHour: modelData.e
                                    readonly property real durationHours: Math.max(0.5, endHour - startHour)
                                    readonly property real _colWidth: (timelineColumn.width - 48) / modelData.cols

                                    x: 44 + modelData.col * _colWidth
                                    y: startHour * AppConfig.calendarDayViewHourHeight
                                    width: _colWidth - (modelData.cols > 1 ? 2 : 0)
                                    height: Math.max(30, durationHours * AppConfig.calendarDayViewHourHeight - 2)
                                    radius: Tokens.shape.small
                                    color: Theme.primaryContainer

                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.top: parent.top
                                        anchors.bottom: parent.bottom
                                        width: 4
                                        radius: Tokens.shape.full
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

                    // Backed, because this sits ON the hour ruler rather than
                    // beside it: centred bare text collided with the hour labels
                    // behind it as soon as the pack widened the face.
                    Surface {
                        anchors.centerIn: parent
                        visible: root.selectedDayEvents.length === 0
                        implicitWidth: dayEmpty.implicitWidth + Tokens.spacing.extraLarge * 2
                        implicitHeight: dayEmpty.implicitHeight + Tokens.spacing.large * 2
                        color: Theme.surfaceContainerHigh
                        radius: Tokens.shape.medium
                        outlined: true

                        EmptyState {
                            id: dayEmpty
                            anchors.centerIn: parent
                            iconName: "event_busy"
                            title: "No events"
                            subtitle: "Press N to add an event"
                        }
                    }
                }

                MaterialButton {
                    Layout.fillWidth: true
                    text: "Add Event"
                    variant: "tonal"
                    enabled: CalendarBackend.calendars.length > 0
                    // QtQuick.Controls ToolTip: tabs have no tooltipManager
                    // plumbing (convention-sanctioned fallback).
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
            if (isEdit && eventData.isOverride) {
                // A moved occurrence edits ITS OWN override VEVENT —
                // addressing by uid alone would rewrite the whole series.
                CalendarBackend.editEvent(eventData.uid, fields, "all",
                                          eventData.start, eventData.recurrenceId)
            } else if (isEdit && eventData.isRecurringMaster) {
                // Ask user: this occurrence or whole series
                recurrenceChoice.askEdit(eventData, fields)
            } else if (isEdit) {
                CalendarBackend.editEvent(eventData.uid, fields, "all")
            } else {
                CalendarBackend.addEvent(fields)
            }
        }

        onEventDeleted: (uid, isRecurring) => {
            if (eventData && eventData.isOverride) {
                // Deleting a moved occurrence removes the override and
                // EXDATEs the original slot — never the whole series.
                CalendarBackend.deleteEvent(uid, "this",
                                            eventData.start, eventData.recurrenceId)
            } else if (isRecurring) {
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

        onCancelled: (intent, ev, fields) => {
            // Only an edit has anything to lose; a cancelled delete just stops.
            if (intent === "edit")
                eventDialog.openDialog(true, ev, ev.start, fields)
        }
    }
}
