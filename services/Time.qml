pragma Singleton

import Quickshell
import QtQuick

Singleton {
    id: root

    property alias enabled: clock.enabled
    readonly property date date: clock.date
    readonly property int hours: clock.hours
    readonly property int minutes: clock.minutes
    readonly property int seconds: clock.seconds

    // Convenient formatted strings
    readonly property string timeString: Qt.formatDateTime(clock.date, "hh:mm")
    readonly property string timeStringWithSeconds: Qt.formatDateTime(clock.date, "hh:mm:ss")
    readonly property string dateString: Qt.formatDateTime(clock.date, "dd MMM")
    readonly property string fullDateString: Qt.formatDateTime(clock.date, "dddd, MMMM d, yyyy")

    function format(fmt: string): string {
        return Qt.formatDateTime(clock.date, fmt)
    }

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }
}