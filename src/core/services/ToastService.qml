pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    readonly property int Info: 0
    readonly property int Success: 1
    readonly property int Warning: 2
    readonly property int Error: 3

    signal toastRequested(string message, string icon, int level, int duration)

    function info(message, duration) {
        toastRequested(message, "info", Info, duration || 3000)
    }

    function success(message, duration) {
        toastRequested(message, "check_circle", Success, duration || 3000)
    }

    function warning(message, duration) {
        toastRequested(message, "warning", Warning, duration || 4000)
    }

    function error(message, duration) {
        toastRequested(message, "error", Error, duration || 5000)
    }
}
