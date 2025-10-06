pragma Singleton
import QtQuick
import QtQuick.LocalStorage
import Quickshell

Singleton {
    id: root

    property var todayEvents: []
    property var weekEvents: []
    property var upcomingEvents: [] // Top 3 upcoming events for MainTab
    property string lastLoadedDate: Qt.formatDate(new Date(), "yyyy-MM-dd")

    signal eventsChanged()

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
            // Get today's upcoming events + future events, limit 3
            var result = tx.executeSql(
                `SELECT * FROM events
                 WHERE (date = ? AND start_time >= ?) OR date > ?
                 ORDER BY date, start_time
                 LIMIT 3`,
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
