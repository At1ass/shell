pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.src.core.config
import qs.src.core.services

Singleton {
    id: root

    // Public state
    property var events: []           // events for current grid range
    property var dayEvents: []        // events for selected date
    property var upcomingEvents: []   // upcoming N events for QuickTab
    property list<string> calendars    // available khal calendars
    property bool loading: false
    property string lastError: ""
    property string lastLoadedDate: ""

    // Event date map: "yyyy-MM-dd" -> [events]
    property var eventsByDate: ({})
    property int _eventMapVersion: 0

    signal errorOccurred(string message)

    // Reminders
    property var _remindedIds: ({})
    property string _lastReminderDate: ""

    // khal JSON fields we request
    readonly property var _jsonFields: [
        "title", "start-date", "start-time", "end-date", "end-time",
        "location", "description", "calendar", "uid", "categories",
        "all-day", "status"
    ]

    Component.onCompleted: {
        refreshCalendars()
        _loadUpcoming()
    }

    // ── Processes ──────────────────────────────────────────────────

    Process {
        id: rangeProc
        property list<string> _lines: []

        stdout: SplitParser {
            onRead: (line) => { rangeProc._lines.push(line) }
        }

        onExited: (exitCode, exitStatus) => {
            root.loading = false
            if (exitCode !== 0) { rangeProc._lines = []; return }
            const output = rangeProc._lines.join("\n")
            rangeProc._lines = []
            root._handleListResult(output, "range")
        }
    }

    Process {
        id: dayProc
        property list<string> _lines: []

        stdout: SplitParser {
            onRead: (line) => { dayProc._lines.push(line) }
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) { dayProc._lines = []; return }
            const output = dayProc._lines.join("\n")
            dayProc._lines = []
            root._handleListResult(output, "day")
        }
    }

    Process {
        id: upcomingProc
        property list<string> _lines: []

        stdout: SplitParser {
            onRead: (line) => { upcomingProc._lines.push(line) }
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) { upcomingProc._lines = []; return }
            const output = upcomingProc._lines.join("\n")
            upcomingProc._lines = []
            root._handleListResult(output, "upcoming")
        }
    }

    Process {
        id: newProc
        property list<string> _errLines: []

        stderr: SplitParser {
            onRead: (line) => {
                if (!line.includes("DeprecationWarning"))
                    newProc._errLines.push(line)
            }
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0 && newProc._errLines.length > 0) {
                root.lastError = newProc._errLines.join("\n")
                root.errorOccurred(root.lastError)
                ToastService.error("Failed to add event: " + root.lastError)
            } else {
                root.lastError = ""
            }
            newProc._errLines = []
            root._refreshAll()
            _syncTimer.start()
        }
    }

    Process {
        id: deleteProc
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                ToastService.error("Failed to delete event")
            }
            root._refreshAll()
            _syncTimer.start()
        }
    }

    Process {
        id: calProc
        property list<string> _lines: []

        stdout: SplitParser {
            onRead: (line) => { calProc._lines.push(line) }
        }

        onExited: (exitCode, exitStatus) => {
            const result = calProc._lines.filter(l => l.trim().length > 0 && !l.includes("DeprecationWarning") && !l.includes("cpython"))
            calProc._lines = []
            root.calendars = result.length > 0 ? result : ["personal"]
        }
    }

    Process {
        id: reminderProc
        property list<string> _lines: []

        stdout: SplitParser {
            onRead: (line) => { reminderProc._lines.push(line) }
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                reminderProc._lines = []
                return
            }
            const output = reminderProc._lines.join("\n")
            reminderProc._lines = []
            root._handleReminderResult(output)
        }
    }

    Process {
        id: notifyProc
    }

    Process {
        id: syncProc
        command: ["vdirsyncer", "sync"]
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                ToastService.warning("Calendar sync failed")
            } else {
                root._refreshAll()
            }
        }
    }

    // ── Public API ────────────────────────────────────────────────

    function loadEventsForRange(startDate, endDate) {
        const startStr = Qt.formatDate(startDate, "dd.MM.yyyy")
        const endStr = Qt.formatDate(endDate, "dd.MM.yyyy")
        _lastRangeStart = startStr
        _lastRangeEnd = endStr
        root.loading = true
        rangeProc._lines = []
        rangeProc.command = _buildListCommand(startStr, endStr)
        rangeProc.running = true
    }

    function loadEventsForDate(dateString) {
        lastLoadedDate = dateString
        const parts = dateString.split("-")
        const khalDate = parts[2] + "." + parts[1] + "." + parts[0]
        dayProc._lines = []
        dayProc.command = _buildListCommand(khalDate, "2d")
        dayProc.running = true
    }

    function addEvent(calendar, startDate, startTime, endTime, title, description, location, categories, recurrence, until) {
        const cmd = _buildNewCommand(calendar, startDate, startTime, endTime, title, description, location, categories, recurrence, until)
        newProc._errLines = []
        newProc.command = cmd
        newProc.running = true
    }

    function deleteEvent(uid, calendar) {
        deleteProc.command = ["bash", "-c",
            "find ~/.local/share/khal/calendars/ -name '*.ics' -exec grep -l 'UID:" + uid + "' {} \\; | head -1 | xargs rm -f"
        ]
        deleteProc.running = true
    }

    function refreshCalendars() {
        calProc._lines = []
        calProc.command = ["khal", "printcalendars"]
        calProc.running = true
    }

    function hasEventsOnDate(dateString) {
        return (root.eventsByDate[dateString] || []).length > 0
    }

    function getEventsOnDate(dateString) {
        return root.eventsByDate[dateString] || []
    }

    function eventCountOnDate(dateString) {
        // Reading _eventMapVersion creates a binding dependency for reactive updates
        return root._eventMapVersion >= 0 ? (root.eventsByDate[dateString] || []).length : 0
    }

    // ── Reminders ─────────────────────────────────────────────────

    Timer {
        id: reminderTimer
        interval: 60 * 1000
        repeat: true
        running: AppConfig.calendarRemindersEnabled
        triggeredOnStart: true
        onTriggered: root._checkReminders()
    }

    function _checkReminders() {
        if (!AppConfig.calendarRemindersEnabled) return
        const now = new Date()
        const todayStr = Qt.formatDate(now, "yyyy-MM-dd")

        if (todayStr !== root._lastReminderDate) {
            root._remindedIds = {}
            root._lastReminderDate = todayStr
        }

        const khalToday = Qt.formatDate(now, "dd.MM.yyyy")
        reminderProc._lines = []
        reminderProc.command = _buildListCommand(khalToday, "2d")
        reminderProc.running = true
    }

    function _handleReminderResult(output) {
        const events = _parseKhalOutput(output)
        const now = new Date()
        const nowMs = now.getTime()
        const lookaheadMs = AppConfig.calendarReminderMinutes * 60 * 1000

        for (const ev of events) {
            if (ev.allDay || !ev.startTime) continue
            const key = ev.uid || (ev.title + ev.startDate + ev.startTime)
            if (root._remindedIds[key]) continue

            const dateParts = ev.startDate.replace(/\.$/, "").split(".")
            const timeParts = ev.startTime.split(":")
            const eventDate = new Date(
                parseInt(dateParts[2]) || now.getFullYear(),
                (parseInt(dateParts[1]) || 1) - 1,
                parseInt(dateParts[0]) || 1,
                parseInt(timeParts[0]) || 0,
                parseInt(timeParts[1]) || 0
            )
            const delta = eventDate.getTime() - nowMs

            if (delta > 0 && delta <= lookaheadMs) {
                const minutes = Math.round(delta / 60000)
                root._remindedIds = Object.assign({}, root._remindedIds, { [key]: true })
                _sendReminder(ev.title, ev.startTime, minutes)
            }
        }
    }

    function _sendReminder(title, time, minutes) {
        notifyProc.command = [
            "notify-send",
            "--urgency=normal",
            "--app-name=Calendar",
            "--icon=calendar",
            "Upcoming: " + title,
            "Starting at " + time + " (in " + minutes + " min)"
        ]
        notifyProc.running = true
    }

    // ── Auto-refresh & sync ─────────────────────────────────────

    Timer {
        interval: 5 * 60 * 1000
        repeat: true
        running: true
        onTriggered: {
            syncProc.running = true
            root._refreshAll()
        }
    }

    Timer {
        id: _syncTimer
        interval: 1000
        repeat: false
        onTriggered: syncProc.running = true
    }

    // ── Upcoming events for QuickTab ──────────────────────────────

    function _loadUpcoming() {
        const now = new Date()
        const khalToday = Qt.formatDate(now, "dd.MM.yyyy")
        upcomingProc._lines = []
        upcomingProc.command = _buildListCommand(khalToday, "7d")
        upcomingProc.running = true
    }

    // ── Internal ──────────────────────────────────────────────────

    // Store last range for refresh
    property string _lastRangeStart: ""
    property string _lastRangeEnd: ""

    function _refreshAll() {
        if (lastLoadedDate) loadEventsForDate(lastLoadedDate)
        if (_lastRangeStart && _lastRangeEnd) {
            rangeProc._lines = []
            rangeProc.command = _buildListCommand(_lastRangeStart, _lastRangeEnd)
            rangeProc.running = true
        }
        _refreshUpcomingTimer.start()
    }

    Timer {
        id: _refreshUpcomingTimer
        interval: 300
        repeat: false
        onTriggered: root._loadUpcoming()
    }

    function _buildListCommand(start, end) {
        const cmd = ["khal", "list", "--day-format", ""]
        for (const field of _jsonFields) {
            cmd.push("--json")
            cmd.push(field)
        }
        cmd.push(start)
        cmd.push(end)
        return cmd
    }

    function _buildNewCommand(calendar, startDate, startTime, endTime, title, description, location, categories, recurrence, until) {
        // startDate: "yyyy-MM-dd" -> "dd.MM.yyyy" for khal
        const parts = startDate.split("-")
        const khalDate = parts[2] + "." + parts[1] + "." + parts[0]

        const cmd = ["khal", "new"]
        if (calendar) {
            cmd.push("-a")
            cmd.push(calendar)
        }
        if (location) {
            cmd.push("-l")
            cmd.push(location)
        }
        if (categories) {
            cmd.push("-g")
            cmd.push(categories)
        }
        if (recurrence && recurrence !== "none") {
            cmd.push("-r")
            cmd.push(recurrence)
            if (until) {
                const untilParts = until.split("-")
                cmd.push("-u")
                cmd.push(untilParts[2] + "." + untilParts[1] + "." + untilParts[0])
            }
        }

        // Date and time
        if (startTime && endTime) {
            cmd.push(khalDate)
            cmd.push(startTime)
            cmd.push(endTime)
        } else if (startTime) {
            cmd.push(khalDate)
            cmd.push(startTime)
        } else {
            cmd.push(khalDate)
        }

        // Title + description
        let eventStr = title
        if (description) {
            eventStr += " :: " + description
        }
        cmd.push(eventStr)

        return cmd
    }

    function _handleListResult(output, callback) {
        const allEvents = _parseKhalOutput(output)

        if (callback === "range") {
            root.events = allEvents
            _buildEventsByDate(allEvents)
        } else if (callback === "day") {
            const targetDate = lastLoadedDate
            root.dayEvents = allEvents.filter(ev => {
                const evDate = _khalDateToIso(ev.startDate)
                return evDate === targetDate
            })
        } else if (callback === "upcoming") {
            const now = new Date()
            const todayStr = Qt.formatDate(now, "yyyy-MM-dd")
            const currentTime = Qt.formatTime(now, "HH:mm")
            const upcoming = allEvents.filter(ev => {
                if (ev.allDay) return true
                const evDate = _khalDateToIso(ev.startDate)
                if (evDate > todayStr) return true
                if (evDate === todayStr && ev.startTime >= currentTime) return true
                return false
            })
            root.upcomingEvents = upcoming.slice(0, AppConfig.calendarUpcomingCount)
        }
    }

    function _parseKhalOutput(output) {
        if (!output) return []
        const allEvents = []
        const lines = output.split("\n")
        for (const line of lines) {
            const trimmed = line.trim()
            if (!trimmed || !trimmed.startsWith("[")) continue
            try {
                const dayEvents = JSON.parse(trimmed)
                for (const ev of dayEvents) {
                    allEvents.push({
                        title: ev.title || "",
                        startDate: ev["start-date"] || "",
                        startTime: ev["start-time"] || "",
                        endDate: ev["end-date"] || "",
                        endTime: ev["end-time"] || "",
                        location: ev.location || "",
                        description: ev.description || "",
                        calendar: ev.calendar || "",
                        uid: ev.uid || "",
                        categories: ev.categories || "",
                        allDay: ev["all-day"] === "True",
                        status: ev.status || ""
                    })
                }
            } catch (e) {
                // skip unparseable lines
            }
        }
        return allEvents
    }

    function _buildEventsByDate(eventList) {
        const map = {}
        for (const ev of eventList) {
            const isoDate = _khalDateToIso(ev.startDate)
            if (!isoDate) continue
            if (!map[isoDate]) map[isoDate] = []
            map[isoDate].push(ev)
        }
        root.eventsByDate = map
        root._eventMapVersion++
    }

    // "06.03." or "06.03.2026" -> "2026-03-06"
    function _khalDateToIso(khalDate) {
        if (!khalDate) return ""
        const parts = khalDate.replace(/\.$/, "").split(".")
        if (parts.length < 2) return ""
        const day = parts[0].padStart(2, "0")
        const month = parts[1].padStart(2, "0")
        const year = parts.length >= 3 && parts[2] ? parts[2] : new Date().getFullYear().toString()
        return year + "-" + month + "-" + day
    }
}
