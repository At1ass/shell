pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.src.core.config

Singleton {
    id: root

    property bool enabled: false

    // Runtime override (IPC) wins while set; config hot-reload keeps
    // working because the base stays a live binding — a plain read-write
    // property would sever it on the first setTemperature() call.
    property int _temperatureOverride: 0
    readonly property int temperature: _temperatureOverride > 0
        ? _temperatureOverride
        : AppConfig.nightLightTemperature

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
            // Whatever ended this run (temperature restart, crash), if the
            // user still wants night light — bring it back. The old code
            // bailed when the previous instance had not exited yet and
            // never retried, leaving enabled=true with no hyprsunset.
            if (root.enabled)
                _restartTimer.restart()
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
        onTriggered: {
            if (root.enabled) root._startSunset()
        }
    }

    function toggle() {
        if (!_detected) {
            ToastService.warning("hyprsunset not found - night light unavailable")
            return
        }
        enabled = !enabled
    }

    function setTemperature(temp) {
        _temperatureOverride = Math.max(1000, Math.min(6500, temp))
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
