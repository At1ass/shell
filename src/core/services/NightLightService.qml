pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.src.core.config

Singleton {
    id: root

    function init() {}

    // USER state, so it lives in state.json: a plain in-memory bool reset to
    // false on every restart and every QML hot-reload, silently dropping the
    // filter while the toggle still read as off. Derive-from-state /
    // write-to-state, the shape NotificationDND documents.
    readonly property bool enabled: AppConfig.stateData?.nightLight?.enabled ?? false

    // Runtime override (IPC) wins while set; config hot-reload keeps
    // working because the base stays a live binding — a plain read-write
    // property would sever it on the first setTemperature() call.
    property int _temperatureOverride: 0
    readonly property int temperature: _temperatureOverride > 0
        ? _temperatureOverride
        : AppConfig.nightLightTemperature

    // Whether hyprsunset is available on the system
    readonly property bool available: _detected
    readonly property bool active: sunsetProc.running && !_awaitingExit
    property string errorMessage: ""
    property int lastExitCode: 0
    readonly property bool canRetry: (enabled || errorMessage !== "") && !sunsetProc.running && !_awaitingExit && !detectProc.running
    readonly property string statusText: errorMessage !== "" ? "Recovery needed" : enabled ? active ? "On" : "Starting…" : "Off"
    property bool _detected: false
    property int _consecutiveFailures: 0
    property bool _awaitingExit: false
    property bool _intentionalStop: false
    readonly property int _retryDelay: Math.min(30000, 150 * Math.pow(2, _consecutiveFailures))

    Process {
        id: detectProc
        objectName: "nightLightDetect"
        command: ["which", "hyprsunset"]
        onExited: (exitCode) => {
            root._detected = exitCode === 0
            if (exitCode !== 0 && root.enabled) root.reportError("Night light is unavailable. Install hyprsunset and retry.", exitCode)
        }
    }

    Process {
        id: sunsetProc
        objectName: "nightLightProcess"
        command: ["hyprsunset", "-t", root.temperature.toString()]

        onExited: (exitCode) => {
            const intentional = root._intentionalStop
            root._intentionalStop = false
            root._awaitingExit = false
            stopDeadline.stop()
            if (!root.enabled) return
            if (!intentional) {
                root._consecutiveFailures = Math.min(8, root._consecutiveFailures + 1)
                root.reportError("Night light stopped unexpectedly. Automatic recovery is in progress.", exitCode)
            }
            _restartTimer.restart()
        }
    }

    Timer {
        objectName: "nightLightHealthy"
        interval: 30000
        running: sunsetProc.running && (root._consecutiveFailures > 0 || root.errorMessage !== "")
        onTriggered: { root._consecutiveFailures = 0; root.errorMessage = ""; root.lastExitCode = 0 }
    }

    Timer {
        id: stopDeadline
        objectName: "nightLightStopDeadline"
        interval: 3000
        onTriggered: if (root._awaitingExit) sunsetProc.signal(9)
    }

    onEnabledChanged: {
        _consecutiveFailures = 0
        _restartTimer.stop()
        if (enabled) {
            _startSunset()
        } else {
            _stopSunset()
            errorMessage = ""
        }
    }

    onTemperatureChanged: {
        if (enabled) {
            _consecutiveFailures = 0
            _stopSunset()
            _restartTimer.restart()
        }
    }

    Connections {
        target: AppConfig
        function onReadyChanged() {
            if (AppConfig.ready && root.enabled) root._startSunset()
        }
    }

    // Fast intentional restarts; unexpected exits use a capped backoff.
    Timer {
        id: _restartTimer
        objectName: "nightLightRetry"
        interval: root._retryDelay
        repeat: false
        onTriggered: {
            if (root.enabled) root._startSunset()
        }
    }

    function setEnabled(on) {
        if (on !== root.enabled)
            AppConfig.updateState("nightLight", { "enabled": on })
    }

    function toggle() {
        if (!_detected && !enabled) {
            root.reportError("Night light is unavailable. Install hyprsunset and retry.", -1)
            return
        }
        root.setEnabled(!root.enabled)
    }

    function reportError(message, code) {
        const first = errorMessage === ""
        errorMessage = message
        lastExitCode = code
        if (first) ToastService.warning(message)
    }
    function retry() {
        if (!canRetry) return false
        if (!_detected) {
            detectProc.running = true
            return true
        }
        if (!enabled) return false
        _restartTimer.stop()
        _consecutiveFailures = 0
        _startSunset()
        return sunsetProc.running
    }

    function setTemperature(temp) {
        if (!Number.isFinite(temp)) return
        _temperatureOverride = Math.max(1000, Math.min(6500, temp))
    }

    function _startSunset() {
        if (!root.enabled || !AppConfig.ready || !_detected || _awaitingExit || sunsetProc.running) return
        sunsetProc.command = ["hyprsunset", "-t", root.temperature.toString()]
        sunsetProc.running = true
    }

    function _stopSunset() {
        if (sunsetProc.running && !_awaitingExit) {
            _intentionalStop = true
            _awaitingExit = true
            stopDeadline.restart()
            sunsetProc.running = false
        }
    }

    // State is restored from disk before `which hyprsunset` has answered, so an
    // enable coming back from state.json hits _startSunset() while _detected is
    // still false and is dropped. Start once detection lands.
    on_DetectedChanged: {
        if (root._detected && !root.enabled) root.errorMessage = ""
        if (root._detected && root.enabled)
            root._startSunset()
    }

    Component.onCompleted: {
        detectProc.running = true
    }
    IpcHandler {
        target: "nightlight"
        function retry(): bool { return root.retry() }
        function status(): string {
            return JSON.stringify({enabled:root.enabled,available:root.available,active:root.active,
                error:root.errorMessage,exitCode:root.lastExitCode,retryScheduled:_restartTimer.running})
        }
    }
}
