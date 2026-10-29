pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // One clock for the whole shell. Minute precision: nothing here needs to
    // re-evaluate 60x more often than the coarsest thing it feeds.
    property var clock: SystemClock {
        precision: SystemClock.Minutes
    }

    // Consumers that actually DISPLAY uptime hold a watcher while alive. The
    // only one is the dashboard's Quick tab, which exists for the seconds the
    // panel is open — and /proc/uptime is readable only by polling. Unlike
    // metric history, uptime has no samples to retain while hidden.
    property int uptimeWatchers: 0
    function addUptimeWatcher()    { root.uptimeWatchers++ }
    function removeUptimeWatcher() { root.uptimeWatchers = Math.max(0, root.uptimeWatchers - 1) }

    property string uptime: ""
    Timer {
        interval: 60000
        running: root.uptimeWatchers > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: fileUptime.reload()
    }
    FileView {
        id: fileUptime
        path: "/proc/uptime"
        onLoaded: {
            const seconds = Number(text().split(" ")[0])
            if (!Number.isFinite(seconds) || seconds < 0) { root.uptime = ""; return }
            const days = Math.floor(seconds / 86400)
            const hours = Math.floor((seconds % 86400) / 3600)
            const minutes = Math.floor((seconds % 3600) / 60)
            const parts = []
            if (days > 0) parts.push(`${days}d`)
            if (hours > 0) parts.push(`${hours}h`)
            if (minutes > 0 || parts.length === 0) parts.push(`${minutes}m`)
            root.uptime = parts.join(", ")
        }
        onLoadFailed: root.uptime = ""
    }
}
