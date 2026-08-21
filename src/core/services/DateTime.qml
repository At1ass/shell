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
    // panel is open — and /proc/uptime is readable only by polling. Same gate
    // as SystemMonitorService.isMonitoring and KeyboardLayoutService's lock
    // state: poll exactly while something is on screen to read the result.
    property int uptimeWatchers: 0
    function addUptimeWatcher()    { root.uptimeWatchers++ }
    function removeUptimeWatcher() { root.uptimeWatchers = Math.max(0, root.uptimeWatchers - 1) }

    property string uptime: "0h, 0m"

    // 60s, not 3s: the string this produces is `Nd, Nh, Nm`, so a finer poll
    // cannot change what is displayed. triggeredOnStart keeps the value fresh
    // the moment a watcher appears.
    Timer {
        interval: 60000
        running: root.uptimeWatchers > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            fileUptime.reload()
            const textUptime = fileUptime.text()
            const uptimeSeconds = Number(textUptime.split(" ")[0] ?? 0)

            // Convert seconds to days, hours, and minutes
            const days = Math.floor(uptimeSeconds / 86400)
            const hours = Math.floor((uptimeSeconds % 86400) / 3600)
            const minutes = Math.floor((uptimeSeconds % 3600) / 60)

            // Build the formatted uptime string
            let formatted = ""
            if (days > 0) formatted += `${days}d`
            if (hours > 0) formatted += `${formatted ? ", " : ""}${hours}h`
            if (minutes > 0 || !formatted) formatted += `${formatted ? ", " : ""}${minutes}m`
            root.uptime = formatted
        }
    }

    FileView {
        id: fileUptime
        path: "/proc/uptime"
    }
}
