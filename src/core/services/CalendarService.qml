pragma Singleton
import QtQuick
import QtQuick.LocalStorage
import Quickshell
import Quickshell.Io
import qs.src.core.config

Singleton {
    id: root

    property var todayEvents: []
    property var weekEvents: []
    property var upcomingEvents: [] // Top 2 upcoming events for QuickTab
    property string lastLoadedDate: Qt.formatDate(new Date(), "yyyy-MM-dd")

    signal eventsChanged()

    // ── Reminders ──────────────────────────────────────────────────
    property var _remindedIds: ({})
    property string _lastReminderDate: ""

    Process {
        id: reminderProc
    }

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

        // Reset daily
        if (todayStr !== root._lastReminderDate) {
            root._remindedIds = {}
            root._lastReminderDate = todayStr
        }

        const lookaheadMs = AppConfig.calendarReminderMinutes * 60 * 1000
        const nowMs = now.getTime()

        var db = getDatabase()
        db.transaction(tx => {
            var result = tx.executeSql(
                'SELECT * FROM events WHERE date = ? ORDER BY start_time',
                [todayStr]
            )
            for (var i = 0; i < result.rows.length; i++) {
                var row = result.rows.item(i)
                const key = String(row.id)
                if (root._remindedIds[key]) continue

                const parts = (row.start_time || "00:00").split(":")
                const eventDate = new Date(now)
                eventDate.setHours(parseInt(parts[0]) || 0, parseInt(parts[1]) || 0, 0, 0)
                const delta = eventDate.getTime() - nowMs

                if (delta > 0 && delta <= lookaheadMs) {
                    const minutes = Math.round(delta / 60000)
                    root._remindedIds = Object.assign({}, root._remindedIds, { [key]: true })
                    reminderProc.command = [
                        "notify-send",
                        "--urgency=normal",
                        "--app-name=Calendar",
                        "--icon=calendar",
                        "Upcoming: " + row.title,
                        "Starting at " + row.start_time + " (in " + minutes + " min)"
                    ]
                    reminderProc.running = true
                }
            }
        })
    }

    // ───────────────────────────────────────────────────────────────

    Component.onCompleted: {
        initDatabase()
        loadTodayEvents()
    }

    function getDatabase() {
        return LocalStorage.openDatabaseSync(
            "QuickshellCalendar",
            "1.0",
            "Calendar Events Database",
            1000000
        )
    }

    function initDatabase() {
        var db = getDatabase()
        db.transaction(tx => {
            tx.executeSql(`
                CREATE TABLE IF NOT EXISTS events (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    date TEXT NOT NULL,
                    start_time TEXT NOT NULL,
                    end_time TEXT,
                    title TEXT NOT NULL,
                    description TEXT,
                    color TEXT DEFAULT 'primary',
                    created_at TEXT DEFAULT CURRENT_TIMESTAMP
                )
            `)
            tx.executeSql('CREATE INDEX IF NOT EXISTS idx_events_date ON events(date)')

            // Add sample data if empty
            var result = tx.executeSql('SELECT COUNT(*) as count FROM events')
        })
    }

    function insertSampleData(tx) {
        const today = Qt.formatDate(new Date(), "yyyy-MM-dd")

        tx.executeSql('INSERT INTO events (date, start_time, end_time, title, description, color) VALUES (?, ?, ?, ?, ?, ?)',
            [today, '14:30', '15:30', 'Meeting', 'Team sync meeting', 'primary'])
        tx.executeSql('INSERT INTO events (date, start_time, end_time, title, description, color) VALUES (?, ?, ?, ?, ?, ?)',
            [today, '16:00', '17:00', 'Code Review', 'Review PR #123', 'secondary'])
        tx.executeSql('INSERT INTO events (date, start_time, end_time, title, description, color) VALUES (?, ?, ?, ?, ?, ?)',
            [today, '18:00', '18:30', 'Standup', 'Daily standup', 'tertiary'])
    }

    function loadTodayEvents() {
        const today = Qt.formatDate(new Date(), "yyyy-MM-dd")
        loadEventsByDate(today)  // This will also update lastLoadedDate
        loadUpcomingEvents()
    }

    function loadUpcomingEvents() {
        var db = getDatabase()
        var events = []

        const now = new Date()
        const currentTime = Qt.formatTime(now, "HH:mm")
        const today = Qt.formatDate(now, "yyyy-MM-dd")

        db.transaction(tx => {
            // Get today's upcoming events + future events, limit 2
            var result = tx.executeSql(
                `SELECT * FROM events
                 WHERE (date = ? AND start_time >= ?) OR date > ?
                 ORDER BY date, start_time
                 LIMIT 2`,
                [today, currentTime, today]
            )

            for (var i = 0; i < result.rows.length; i++) {
                var row = result.rows.item(i)
                events.push({
                    id: row.id,
                    date: row.date,
                    startTime: row.start_time,
                    endTime: row.end_time,
                    title: row.title,
                    description: row.description || '',
                    color: row.color,
                    time: row.start_time + (row.end_time ? '-' + row.end_time : '')
                })
            }
        })

        upcomingEvents = events
    }

    function loadEventsByDate(date) {
        lastLoadedDate = date
        var db = getDatabase()
        var events = []

        db.transaction(tx => {
            var result = tx.executeSql(
                'SELECT * FROM events WHERE date = ? ORDER BY start_time',
                [date]
            )

            for (var i = 0; i < result.rows.length; i++) {
                var row = result.rows.item(i)
                events.push({
                    id: row.id,
                    date: row.date,
                    startTime: row.start_time,
                    endTime: row.end_time,
                    title: row.title,
                    description: row.description || '',
                    color: row.color,
                    time: row.start_time + (row.end_time ? '-' + row.end_time : '')
                })
            }
        })

        todayEvents = events
        eventsChanged()
    }

    function loadWeekEvents() {
        var db = getDatabase()
        var events = []

        const today = new Date()
        const weekLater = new Date(today.getTime() + 7 * 24 * 60 * 60 * 1000)
        const todayStr = Qt.formatDate(today, "yyyy-MM-dd")
        const weekLaterStr = Qt.formatDate(weekLater, "yyyy-MM-dd")

        db.transaction(tx => {
            var result = tx.executeSql(
                'SELECT * FROM events WHERE date BETWEEN ? AND ? ORDER BY date, start_time',
                [todayStr, weekLaterStr]
            )

            for (var i = 0; i < result.rows.length; i++) {
                var row = result.rows.item(i)
                events.push({
                    id: row.id,
                    date: row.date,
                    startTime: row.start_time,
                    endTime: row.end_time,
                    title: row.title,
                    description: row.description || '',
                    color: row.color,
                    time: row.start_time + (row.end_time ? '-' + row.end_time : '')
                })
            }
        })

        weekEvents = events
        eventsChanged()
    }

    function addEvent(date, startTime, endTime, title, description, color) {
        var db = getDatabase()

        db.transaction(tx => {
            tx.executeSql(
                'INSERT INTO events (date, start_time, end_time, title, description, color) VALUES (?, ?, ?, ?, ?, ?)',
                [date, startTime, endTime, title, description || '', color || 'primary']
            )
        })

        // Reload currently viewed date
        loadEventsByDate(lastLoadedDate)
        loadWeekEvents()
        loadUpcomingEvents()
    }

    function updateEvent(id, date, startTime, endTime, title, description, color) {
        var db = getDatabase()

        db.transaction(tx => {
            tx.executeSql(
                'UPDATE events SET date = ?, start_time = ?, end_time = ?, title = ?, description = ?, color = ? WHERE id = ?',
                [date, startTime, endTime, title, description || '', color || 'primary', id]
            )
        })

        // Reload currently viewed date
        loadEventsByDate(lastLoadedDate)
        loadWeekEvents()
        loadUpcomingEvents()
    }

    function deleteEvent(id) {
        var db = getDatabase()

        db.transaction(tx => {
            tx.executeSql('DELETE FROM events WHERE id = ?', [id])
        })

        // Reload currently viewed date
        loadEventsByDate(lastLoadedDate)
        loadWeekEvents()
        loadUpcomingEvents()
    }

    // Auto-refresh every 5 minutes
    Timer {
        interval: 5 * 60 * 1000
        repeat: true
        running: true
        onTriggered: {
            root.loadEventsByDate(root.lastLoadedDate)
            root.loadWeekEvents()
            root.loadUpcomingEvents()
        }
    }
}
