pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.src.core.config

Singleton {
    id: root

    property bool enabled: false
    property int temperature: AppConfig.nightLightTemperature

    // Whether hyprsunset is available on the system
    readonly property bool available: _detected
    property bool _detected: false

    Process {
        id: detectProc
        command: ["which", "hyprsunset"]
        onExited: (exitCode) => {
            root._detected = exitCode === 0
        }
    }

    Process {
        id: sunsetProc
        command: ["hyprsunset", "-t", root.temperature.toString()]

        onExited: (exitCode) => {
            if (exitCode !== 0 && root.enabled)
                console.warn("NightLightService: hyprsunset exited with code", exitCode)
        }
    }

    onEnabledChanged: {
        if (enabled) {
            _startSunset()
        } else {
            _stopSunset()
        }
    }

    onTemperatureChanged: {
        if (enabled) {
            _stopSunset()
            _restartTimer.restart()
        }
    }

    // Small delay when changing temperature to avoid rapid restarts
    Timer {
        id: _restartTimer
        interval: 150
        repeat: false
        onTriggered: root._startSunset()
    }

    function toggle() {
        enabled = !enabled
    }

    function setTemperature(temp) {
        temperature = Math.max(1000, Math.min(6500, temp))
    }

    function _startSunset() {
        if (!_detected || sunsetProc.running) return
        sunsetProc.command = ["hyprsunset", "-t", root.temperature.toString()]
        sunsetProc.running = true
    }

    function _stopSunset() {
        if (sunsetProc.running)
            sunsetProc.running = false
    }

    Component.onCompleted: {
        detectProc.running = true
    }
}
