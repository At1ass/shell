pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var monitors: []
    readonly property bool available: _ready && monitors.length > 0
    readonly property real brightness: {
        if (!monitors.length) return 0.5
        let sum = 0
        for (const monitor of monitors) sum += monitor.current / monitor.max
        return sum / monitors.length
    }
    signal brightnessAdjusted(real value)

    property bool _ready: false
    property var _displays: []
    property var _confirmed: ({})
    property var _readQueue: []
    property real _desired: -1
    property int _writeGeneration: 0
    property int _setIndex: 0
    property string errorMessage: ""
    property var _active: null
    property int _epoch: 0
    property string _output: ""
    property bool _timedOut: false

    // One transport for all DDC commands: reads and writes never overlap.
    Process {
        id: commandProc
        objectName: "brightnessCommand"
        stdout: StdioCollector { onStreamFinished: root._output = text.slice(0, 65536) }
        onExited: exitCode => {
            const epoch = root._epoch
            Qt.callLater(() => root._finish(epoch, exitCode))
        }
    }
    Timer {
        id: deadline
        objectName: "brightnessDeadline"
        interval: root._active?.kind === "detect" ? 15000 : 5000
        onTriggered: {
            if (!root._active) return
            root._timedOut = true
            if (commandProc.running) commandProc.signal(9)
            else root._finish(root._epoch, -1) // A failed start may have no exited signal.
        }
    }

    function _start(job, argv) {
        if (_active || commandProc.running) return
        _active = job
        _epoch++
        _output = ""
        _timedOut = false
        commandProc.command = argv
        deadline.restart()
        commandProc.running = true
    }
    function _schedule() {
        if (_active || commandProc.running) return
        if (_desired >= 0) {
            if (_setIndex < monitors.length) {
                const monitor = monitors[_setIndex]
                const raw = Math.round(_desired * monitor.max)
                _start({kind: "set", display: monitor.display, generation: _writeGeneration},
                    ["ddcutil", "setvcp", "10", String(raw), "--display", String(monitor.display)])
                return
            }
            _desired = -1
            _setIndex = 0
            _readQueue = _displays.slice()
            if (errorMessage) ToastService.warning(errorMessage)
        }
        if (_readQueue.length) {
            const display = _readQueue[0]
            _readQueue = _readQueue.slice(1)
            _start({kind: "read", display: display, generation: _writeGeneration},
                ["ddcutil", "getvcp", "10", "--display", String(display), "--terse"])
        } else _ready = true
    }
    function _publishDisplay(display) {
        const value = _confirmed[display]
        if (!value) return
        const updated = monitors.slice()
        let index = -1
        for (let i = 0; i < updated.length; i++) {
            if (updated[i].display === display) { index = i; break }
        }
        if (index >= 0) updated[index] = value
        else updated.push(value)
        monitors = updated
    }
    function _finish(epoch, exitCode) {
        if (!_active || epoch !== _epoch) return
        deadline.stop()
        const job = _active
        const output = _output
        const success = exitCode === 0 && !_timedOut
        _active = null
        if (job.kind === "detect") {
            const displays = []
            if (success) {
                for (const line of output.split("\n")) {
                    const match = line.match(/^Display\s+(\d+)\b/)
                    const display = match ? Number(match[1]) : 0
                    if (display > 0 && display <= 256 && !displays.includes(display)) displays.push(display)
                    if (displays.length >= 16) break
                }
            } else ToastService.warning("Brightness unavailable: ddcutil detection failed")
            _displays = displays
            _readQueue = displays.slice()
        } else if (job.kind === "read" && job.generation === _writeGeneration) {
            // Current ddcutil: "VCP 10 C <current> <max>". Accept the old prefix-less form too.
            const match = success ? output.trim().match(/^(?:VCP\s+)?10\s+C\s+(\d+)\s+(\d+)$/) : null
            const current = match ? Number(match[1]) : -1
            const maximum = match ? Number(match[2]) : 0
            if (maximum > 0 && maximum <= 65535 && current >= 0 && current <= maximum)
                _confirmed[job.display] = {display: job.display, current: current, max: maximum}
            // Readback failure restores the last confirmed value, not an optimistic write.
            _publishDisplay(job.display)
        } else if (job.kind === "set" && job.generation === _writeGeneration) {
            if (!success) errorMessage = "Could not set display brightness"
            _setIndex++
        }
        _schedule()
    }

    function setBrightness(value) {
        if (!available || !Number.isFinite(value)) return false
        const clamped = Math.max(0, Math.min(1, value))
        _writeGeneration++
        _setIndex = 0
        _desired = clamped
        errorMessage = ""
        const updated = []
        for (const monitor of monitors)
            updated.push({display: monitor.display, current: Math.round(clamped * monitor.max), max: monitor.max})
        monitors = updated
        brightnessAdjusted(clamped)
        _schedule()
        return true
    }
    function increase(step) { return setBrightness(brightness + (step || 0.05)) }
    function decrease(step) { return setBrightness(brightness - (step || 0.05)) }
    Component.onCompleted: _start({kind: "detect"}, ["ddcutil", "detect", "--terse"])
}
