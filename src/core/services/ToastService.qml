pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    // Level constants (lowercase — QML doesn't allow uppercase property names)
    readonly property int levelInfo: 0
    readonly property int levelSuccess: 1
    readonly property int levelWarning: 2
    readonly property int levelError: 3

    signal toastRequested(string message, string icon, int level, int duration)

    function info(message, duration) {
        toastRequested(message, "info", levelInfo, duration || 3000)
    }

    function success(message, duration) {
        toastRequested(message, "check_circle", levelSuccess, duration || 3000)
    }

    function warning(message, duration) {
        toastRequested(message, "warning", levelWarning, duration || 4000)
    }

    function error(message, duration) {
        toastRequested(message, "error", levelError, duration || 5000)
    }
}
