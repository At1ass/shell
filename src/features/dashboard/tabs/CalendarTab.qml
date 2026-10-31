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
    property bool _initialized: false
    onTodayChanged: if (_initialized) Qt.callLater(root.updateCalendar)

    // Modal state for DashboardContent's key routing: while a dialog is up,
    // dashboard-level keys (Escape/tab digits) must not fire.
    readonly property bool modalOpen: eventDialog.visible || recurrenceChoice.visible
    function closeTopModal() {
        if (recurrenceChoice.visible) recurrenceChoice.close()
        else if (eventDialog.visible) eventDialog.requestClose()
    }
    property var selectedDayEvents: CalendarBackend.dayEvents
    Shortcut {
        sequence: "Ctrl+F"
        enabled: GlobalStates.dashboardOpen && GlobalStates.dashboardOpenIndex === 2 && !root.modalOpen
        onActivated: eventSearch.focusSearch()
    }

    // Keep rendering comparison separate from the deferred midnight refresh:
    // evaluating today must not synchronously rewrite selectedDate.
    readonly property bool todayIsSelected:
        selectedDate.getFullYear() === today.getFullYear()
        && selectedDate.getMonth() === today.getMonth()
        && selectedDate.getDate() === today.getDate()

    // Day-header labels rotated to start from AppConfig.calendarFirstDayOfWeek.
    readonly property var _dayNames: {
        const result = []
        for (let i = 0; i < 7; i++) {
            const day = (AppConfig.calendarFirstDayOfWeek + i) % 7
            result.push(Qt.locale().standaloneDayName(day === 0 ? 7 : day, Locale.ShortFormat))
        }
        return result
    }
    readonly property FontMetrics _dayMetrics: FontMetrics {
        font.family: Tokens.typography.fontFamily
        font.pixelSize: Tokens.typography.bodyMedium.size
    }
    readonly property real dayNumberWidth: {
        const font = _dayMetrics.font
        return _dayMetrics.advanceWidth("30")
    }
    readonly property real monthMinimum: 7 * Math.max(Tokens.size.control,
        dayNumberWidth + Tokens.spacing.small * 2)
        + Tokens.spacing.extraSmall * 6 + Tokens.spacing.small * 2
    readonly property bool stacked: width - Tokens.panelPadding * 2
        < monthMinimum + Tokens.size.fieldWidth + Tokens.spacing.medium

    function goToToday() {
        currentYear = today.getFullYear()
        currentMonth = today.getMonth()
        updateCalendar()
    }

    function handleNavigationKey(event) {
        if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) return
        const shift = !!(event.modifiers & Qt.ShiftModifier)
        const key = Keycodes.key(event)

        // Shift+key: month nav / jump to last
        if (shift) {
            if (key === Qt.Key_H) { root.goToPrevMonth(); event.accepted = true }
            else if (key === Qt.Key_L) { root.goToNextMonth(); event.accepted = true }
            else if (key === Qt.Key_G) { root.goToLastDay(); event.accepted = true }
            return
        }

        switch (key) {
            // Arrows + vi h/j/k/l
            case Qt.Key_Left:
            case Qt.Key_H:       root.moveFocusBy(-1); event.accepted = true; break
            case Qt.Key_Right:
            case Qt.Key_L:       root.moveFocusBy(1); event.accepted = true; break
            case Qt.Key_Up:
            case Qt.Key_K:       root.moveFocusBy(-7); event.accepted = true; break
            case Qt.Key_Down:
            case Qt.Key_J:       root.moveFocusBy(7); event.accepted = true; break

            case Qt.Key_Return:
            case Qt.Key_Enter:   root.selectFocused(); event.accepted = true; break

            // Month navigation
            case Qt.Key_PageUp:  root.goToPrevMonth(); event.accepted = true; break
            case Qt.Key_PageDown: root.goToNextMonth(); event.accepted = true; break

            // First/last day
            case Qt.Key_Home:    root.goToFirstDay(); event.accepted = true; break
            case Qt.Key_End:     root.goToLastDay(); event.accepted = true; break

            // g = first day (G handled above with shift)
            case Qt.Key_G:       root.goToFirstDay(); event.accepted = true; break

            case Qt.Key_T:       root.goToToday(); event.accepted = true; break

            // N = new event
            case Qt.Key_N:       root.openNewEvent(); event.accepted = true; break
        }
    }

    // Keyboard navigation
    property int focusedCellIndex: -1
    onFocusedCellIndexChanged: {
        // A grid is one stop in the Tab chain. Move actual focus only if the
        // user is already in it; async event loads must never steal focus.
        const focus = root.Window.window?.activeFocusItem
        if (focus?.parent === monthGrid) {
            const cell = dayRepeater.itemAt(root.focusedCellIndex)
            if (cell) cell.forceActiveFocus(Qt.OtherFocusReason)
        }
    }

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

    Component.onCompleted: { _initialized = true; updateCalendar() }

    // What this tab needs, so the window can be sized to it instead of to a
    // constant kept in a table indexed by tab number. See Dashboard.qml.
    readonly property int contentHeight: panels.implicitHeight + calendarScroll.contentPadding * 2

    ScrollableList {
        id: calendarScroll
        anchors.fill: parent
        contentPadding: root.stacked ? Tokens.spacing.extraSmall : Tokens.panelPadding
        GridLayout {
            id: panels
            Layout.fillWidth: true
            columns: root.stacked ? 1 : 2
            columnSpacing: Tokens.spacing.medium
            rowSpacing: Tokens.spacing.medium

            CalendarSearchSection {
                id: eventSearch
                Layout.fillWidth: true
                Layout.columnSpan: panels.columns
                anchorDate: { const date=new Date(0);date.setFullYear(root.currentYear,root.currentMonth,1);return date }
                onDateRequested: value => {
                    root.currentYear=value.getFullYear();root.currentMonth=value.getMonth()
                    root.updateCalendar()
                    root.selectedDate=value
                    for(let i=0;i<calendarDays.count;i++) {
                        if(root.isSameDate(calendarDays.get(i).date,value)) { root.focusedCellIndex=i;break }
                    }
                    Qt.callLater(() => {
                        if(root.visible && GlobalStates.dashboardOpen && GlobalStates.dashboardOpenIndex===2 && !root.modalOpen)
                            dayRepeater.itemAt(root.focusedCellIndex)?.forceActiveFocus()
                    })
                }
            }

            // Left panel — month grid
            MaterialCard {
                id: monthCard
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: root.monthMinimum
                color: Theme.surfaceContainerHigh
                radius: Tokens.shape.large

                // Stated, because a Pane does not learn it. The column below fills
                // this card by ANCHORS, and an anchored child contributes nothing to
                // its parent's implicit size -- so the card reported almost nothing,
                // the tab's measured height came out short, and the grid was
                // squeezed until the last row of days lost its hover ring.
                implicitHeight: monthColumn.implicitHeight + Tokens.spacing.small * 2

                ColumnLayout {
                    id: monthColumn
                    anchors.fill: parent
                    anchors.margins: Tokens.spacing.small
                    spacing: Tokens.spacing.medium

                    // Month navigation
                    RowLayout {
                        Layout.fillWidth: true

                        IconButton {
                            variant: "standard"
                            Accessible.name: "Previous month"
                            iconName: "chevron_left"
                            iconSize: Tokens.iconSize.large
                            onClicked: root.goToPrevMonth()
                        }

                        MaterialText {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            text: Qt.formatDate(new Date(root.currentYear, root.currentMonth, 1), "MMMM yyyy")
                            textStyle: "titleLarge"
                            colorRole: "onSurface"
                            font.weight: Font.Medium
                        }

                        IconButton {
                            variant: "standard"
                            Accessible.name: "Next month"
                            iconName: "chevron_right"
                            iconSize: Tokens.iconSize.large
                            onClicked: root.goToNextMonth()
                        }
                    }

                    MaterialButton {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Today"
                        variant: "text"
                        enabled: !root.todayIsSelected || root.currentMonth !== root.today.getMonth()
                            || root.currentYear !== root.today.getFullYear()
                        onClicked: root.goToToday()
                    }

                    // Day headers
                    GridLayout {
                        id: monthGrid
                        Layout.fillWidth: true
                        columns: 7
                        columnSpacing: root.stacked ? Tokens.spacing.none : Tokens.spacing.extraSmall
                        rowSpacing: Tokens.spacing.extraSmall
                        uniformCellWidths: true
                        uniformCellHeights: true

                        Repeater {
                            model: root._dayNames
                            MaterialText {
                                id: dayNameLabel
                                required property string modelData

                                elide: Text.ElideRight
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
                            id: dayRepeater
                            model: calendarDays

                            delegate: Surface {
                                id: dayCell

                                // Under `pragma ComponentBehavior: Bound` a delegate
                                // must declare what it takes from the model rather
                                // than inheriting it from the enclosing context.
                                required property var model
                                required property int index

                                Layout.fillWidth: true
                                Layout.preferredHeight: Math.max(Tokens.size.control, Tokens.typography.bodyMedium.lineHeight + Tokens.spacing.medium)
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

                                outlined: dayCell.isFocused || (dayCell.isSelected && dayCell.isToday)
                                outlineColor: dayCell.isFocused ? Theme.tertiary : Theme.onPrimary
                                activeFocusOnTab: dayCell.isFocused || dayCell.activeFocus
                                onActiveFocusChanged: if (activeFocus) root.focusedCellIndex = dayCell.index
                                Accessible.role: Accessible.Button
                                Accessible.name: Qt.formatDate(dayCell.model.date, "dddd, MMMM d, yyyy")
                                Accessible.onPressAction: dayCell._select()
                                function _select() {
                                    root.focusedCellIndex = dayCell.index
                                    root.selectFocused()
                                }
                                Keys.onPressed: event => {
                                    if (event.key === Qt.Key_Space && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
                                        dayCell._select()
                                        event.accepted = true
                                    } else root.handleNavigationKey(event)
                                }
                                StateLayer { target: dayCell; anchors.fill: parent; focused: dayCell.activeFocus; layerColor: Theme.onSurface }

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

                                            MaterialIndicator {
                                                size: "extraSmall"
                                                animated: false
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
                                        dayCell.forceActiveFocus(Qt.MouseFocusReason)
                                        dayCell._select()
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Right panel — day view timeline
            MaterialCard {
                id: dayCard
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: Tokens.size.fieldWidth
                implicitHeight: dayColumn.implicitHeight + Tokens.spacing.medium * 2
                color: Theme.surfaceContainerHigh
                radius: Tokens.shape.large

                ColumnLayout {
                    id: dayColumn
                    anchors.fill: parent
                    anchors.margins: Tokens.spacing.medium
                    spacing: Tokens.spacing.small

                    // Date header
                    MaterialText {
                        text: Qt.formatDate(root.selectedDate, "dddd, MMMM d")
                        wrapMode: Text.Wrap
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

                            Surface {
                                id: allDayChip
                                required property var modelData

                                property int maxWidth: flow.width
                                activeFocusOnTab: true
                                Accessible.role: Accessible.Button
                                Accessible.name: allDayChip.modelData.title
                                Accessible.onPressAction: allDayChip._edit()
                                function _edit() { eventDialog.openDialog(true, allDayChip.modelData, root.selectedDate) }
                                Keys.onPressed: event => {
                                    if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Space) return
                                    if (!event.isAutoRepeat) allDayChip._edit()
                                    event.accepted = true
                                }
                                StateLayer { target: allDayChip; anchors.fill: parent; focused: allDayChip.activeFocus; layerColor: Theme.onTertiaryContainer }

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
                                    onClicked: { allDayChip.forceActiveFocus(Qt.MouseFocusReason); allDayChip._edit() }
                                }
                            }
                        }
                    }

                    Divider {
                        Layout.fillWidth: true
                        visible: root.selectedDayEvents.length > 0
                    }

                    ListItem {
                        Layout.fillWidth: true
                        visible: root.selectedDayEvents.length === 0
                        clickable: false
                        margin: 0
                        headline: "No events"
                        supportingText: CalendarBackend.calendars.length > 0 ? "Your day is free" : "No calendar connected"
                        leadingIcon: "event_available"
                    }

                    // Keep the 24-hour ruler out of empty days and all-day-only views.
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredHeight: Tokens.size.fieldWidth
                        visible: root.selectedDayEvents.some(ev => !ev.allDay)

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

                                        Surface {
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
                                MaterialShape {
                                    visible: root.todayIsSelected
                                    x: 38
                                    width: timelineColumn.width - 38
                                    height: 2
                                    radius: Tokens.shape.full
                                    color: Theme.error
                                    y: (DateTime.clock.date.getHours()
                                        + DateTime.clock.date.getMinutes() / 60)
                                       * AppConfig.calendarDayViewHourHeight

                                    MaterialShape {
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

                                    Surface {
                                        id: eventCard
                                        required property var modelData
                                        readonly property var ev: modelData.ev
                                        readonly property real startHour: modelData.s
                                        readonly property real endHour: modelData.e
                                        readonly property real durationHours: Math.max(0.5, endHour - startHour)
                                        readonly property real _colWidth: (timelineColumn.width - 48) / modelData.cols

                                        activeFocusOnTab: true
                                        Accessible.role: Accessible.Button
                                        Accessible.name: eventCard.ev.title
                                        Accessible.onPressAction: eventCard._edit()
                                        function _edit() { eventDialog.openDialog(true, eventCard.ev, root.selectedDate) }
                                        onActiveFocusChanged: {
                                            if (!activeFocus) return
                                            const top = y
                                            const bottom = y + height
                                            if (top < timelineFlickable.contentY) timelineFlickable.contentY = top
                                            else if (bottom > timelineFlickable.contentY + timelineFlickable.height)
                                                timelineFlickable.contentY = Math.max(0, Math.min(top, bottom - timelineFlickable.height))
                                        }
                                        Keys.onPressed: event => {
                                            if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Space) return
                                            if (!event.isAutoRepeat) eventCard._edit()
                                            event.accepted = true
                                        }
                                        x: 44 + modelData.col * _colWidth
                                        y: startHour * AppConfig.calendarDayViewHourHeight
                                        width: _colWidth - (modelData.cols > 1 ? 2 : 0)
                                        height: Math.max(30, durationHours * AppConfig.calendarDayViewHourHeight - 2)
                                        radius: Tokens.shape.small
                                        color: Theme.primaryContainer

                                        Surface {
                                            anchors.left: parent.left
                                            anchors.top: parent.top
                                            anchors.bottom: parent.bottom
                                            width: 4
                                            radius: Tokens.shape.full
                                            color: Theme.primary
                                        }

                                        StateLayer {
                                            target: eventCard
                                            anchors.fill: parent
                                            layerColor: Theme.onPrimaryContainer
                                            hovered: eventCardMouse.containsMouse
                                            pressed: eventCardMouse.pressed
                                            focused: eventCard.activeFocus
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
                                            onClicked: { eventCard.forceActiveFocus(Qt.MouseFocusReason); eventCard._edit() }
                                        }
                                    }
                                }
                            }
                        }

                    }

                    MaterialButton {
                        Layout.fillWidth: true
                        text: "Add Event"
                        variant: "tonal"
                        enabled: CalendarBackend.calendars.length > 0
                        onClicked: eventDialog.openDialog(false, null, root.selectedDate)
                    }
                    MaterialText {
                        Layout.fillWidth: true
                        visible: CalendarBackend.calendars.length === 0
                        text: "Add a calendar in ~/.config/khal/config to create events."
                        textStyle: "bodySmall"
                        colorRole: "onSurfaceVariant"
                        wrapMode: Text.Wrap
                    }
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
                eventDialog.beginSave(CalendarBackend.editEvent(eventData.uid, fields, "all",
                                          eventData.start, eventData.recurrenceId))
            } else if (isEdit && eventData.isRecurringMaster) {
                // Ask user: this occurrence or whole series
                eventDialog.close()
                recurrenceChoice.askEdit(eventData, fields)
            } else if (isEdit) {
                eventDialog.beginSave(CalendarBackend.editEvent(eventData.uid, fields, "all"))
            } else {
                eventDialog.beginSave(CalendarBackend.addEvent(fields))
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

    Connections {
        target: CalendarBackend
        function onMutationFinished(requestId, success, message) { eventDialog.finishSave(requestId, success, message) }
    }

    RecurrenceEditChoice {
        id: recurrenceChoice
        anchors.fill: parent

        onChoiceMade: (mode, intent, ev, fields) => {
            // mode: "this" | "all"; intent: "edit" | "delete"
            if (intent === "edit") {
                eventDialog.beginSave(CalendarBackend.editEvent(ev.uid, fields, mode, ev.start))
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
