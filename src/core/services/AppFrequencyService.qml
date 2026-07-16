pragma Singleton
import QtQuick
import QtQuick.LocalStorage
import Quickshell

// Singleton tracking application launch frequency
Singleton {
    id: root

    // Cache of top apps (updated on change)
    property var topApps: []

    signal frequencyChanged()

    Component.onCompleted: {
        initDatabase()
        loadTopApps()
    }

    function getDatabase() {
        return LocalStorage.openDatabaseSync(
            "QuickshellLauncher",
            "1.0",
            "Launcher App Frequency Database",
            1000000
        )
    }

    function initDatabase() {
        var db = getDatabase()
        db.transaction(tx => {
            // Create the app launch frequency table
            tx.executeSql(`
                CREATE TABLE IF NOT EXISTS app_frequency (
                    app_id TEXT PRIMARY KEY,
                    frequency INTEGER DEFAULT 0,
                    last_launched TEXT
                )
            `)

            // Index for sorting by frequency
            tx.executeSql('CREATE INDEX IF NOT EXISTS idx_frequency ON app_frequency(frequency DESC)')
        })
    }

    // Increment frequency when an app is launched
    function incrementFrequency(appId) {
        if (!appId) return

        var db = getDatabase()
        const now = new Date().toISOString()

        db.transaction(tx => {
            // SQLite UPSERT: INSERT or UPDATE if it exists
            tx.executeSql(`
                INSERT INTO app_frequency (app_id, frequency, last_launched)
                VALUES (?, 1, ?)
                ON CONFLICT(app_id) DO UPDATE SET
                    frequency = frequency + 1,
                    last_launched = ?
            `, [appId, now, now])
        })

        // Reload the top apps
        loadTopApps()
        frequencyChanged()
    }

    // Get the frequency for a specific app
    function getFrequency(appId) {
        var db = getDatabase()
        var frequency = 0

        db.transaction(tx => {
            var result = tx.executeSql(
                'SELECT frequency FROM app_frequency WHERE app_id = ?',
                [appId]
            )

            if (result.rows.length > 0) {
                frequency = result.rows.item(0).frequency
            }
        })

        return frequency
    }

    // Load top N apps by frequency
    function loadTopApps(limit = 10) {
        var db = getDatabase()
        var apps = []

        db.transaction(tx => {
            var result = tx.executeSql(
                'SELECT app_id, frequency FROM app_frequency ORDER BY frequency DESC LIMIT ?',
                [limit]
            )

            for (var i = 0; i < result.rows.length; i++) {
                var row = result.rows.item(i)
                apps.push({
                    appId: row.app_id,
                    frequency: row.frequency
                })
            }
        })

        topApps = apps
        return apps
    }

    // Get all frequencies (for sorting in ApplicationProvider)
    function getAllFrequencies() {
        var db = getDatabase()
        var frequencies = ({})

        db.transaction(tx => {
            var result = tx.executeSql('SELECT app_id, frequency FROM app_frequency')

            for (var i = 0; i < result.rows.length; i++) {
                var row = result.rows.item(i)
                frequencies[row.app_id] = row.frequency
            }
        })

        return frequencies
    }

    // Clear stats (for debugging)
    function clearStats() {
        var db = getDatabase()
        db.transaction(tx => {
            tx.executeSql('DELETE FROM app_frequency')
        })

        loadTopApps()
        frequencyChanged()
    }
}
