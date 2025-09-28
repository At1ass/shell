import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

Singleton {
    property var clock: SystemClock {
        precision: SystemClock.Minutes
    }

    property string time: Qt.locale().toString(clock.date, "hh:mm")
    property string date: Qt.locale().toString(clock.date, "dddd, dd/MM")
    property string uptime: "0h, 0m"

    Timer {
        interval: 10
        running: true
        repeat: true
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
            uptime = formatted
            interval = 3000
        }
    }

    FileView {
        id: fileUptime
        path: "/proc/uptime"
    }
}