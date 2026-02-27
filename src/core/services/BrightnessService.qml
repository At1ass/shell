pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.src.core.config

Singleton {
    id: root

    // Array of { display: int, current: int, max: int }
    property var monitors: []

    // Primary brightness (0.0–1.0), averaged across all monitors
    readonly property real brightness: {
        if (monitors.length === 0) return 0.5
        let sum = 0
        for (let i = 0; i < monitors.length; i++)
            sum += monitors[i].current / Math.max(monitors[i].max, 1)
        return sum / monitors.length
    }

    readonly property bool available: monitors.length > 0

    // Emitted when brightness is actively changed by the user (not on initial read)
    signal brightnessAdjusted(real value)

    // --- Detect monitors via ddcutil at startup ---
    Process {
        id: detectProc
        command: ["ddcutil", "detect", "--terse"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root._parseDetect(text)
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                console.warn("BrightnessService: ddcutil detect failed (exit " + exitCode + ")")
                ToastService.warning("Brightness unavailable: ddcutil failed")
            }
        }
    }

    function _parseDetect(text) {
        // ddcutil detect --terse outputs lines like:
        // Display 1 ...
        // Display 2 ...
        const displayNums = []
        const lines = text.split("\n")
        for (const line of lines) {
            const m = line.match(/^Display\s+(\d+)/)
            if (m) displayNums.push(parseInt(m[1]))
        }
        if (displayNums.length === 0) {
            console.warn("BrightnessService: no DDC/CI displays found")
            return
        }
        // Initialize monitors array and start reading brightness
        const initial = displayNums.map(n => ({ display: n, current: 50, max: 100 }))
        root.monitors = initial
        _readBrightness(0)
    }

    // --- Sequential brightness read for each monitor ---
    property int _readIndex: 0

    Process {
        id: readProc
        stdout: StdioCollector {
            onStreamFinished: root._parseBrightness(text)
        }
        onExited: (exitCode) => {
            if (exitCode !== 0)
                console.warn("BrightnessService: ddcutil getvcp failed (exit " + exitCode + ")")
        }
    }

    function _readBrightness(index) {
        if (index >= monitors.length) return
        _readIndex = index
        readProc.command = ["ddcutil", "getvcp", "10",
                            "--display", String(monitors[index].display),
                            "--terse"]
        readProc.running = true
    }

    function _parseBrightness(text) {
        // terse output: "10 C <current> <max>"
        const parts = text.trim().split(/\s+/)
        if (parts.length >= 4) {
            const current = parseInt(parts[2])
            const max = parseInt(parts[3])
            if (!isNaN(current) && !isNaN(max) && max > 0) {
                const updated = monitors.slice()
                updated[_readIndex] = { display: monitors[_readIndex].display, current: current, max: max }
                monitors = updated
            }
        }
        _readBrightness(_readIndex + 1)
    }

    // --- Set brightness on all monitors sequentially ---
    property int _setIndex: 0
    property int _setPending: -1

    Process {
        id: setProc
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                console.warn("BrightnessService: ddcutil setvcp failed (exit " + exitCode + ")")
            root._setIndex++
            root._doSetNext()
        }
    }

    function setBrightness(value) {
        const clamped = Math.max(0.0, Math.min(1.0, value))
        const updated = monitors.slice()
        for (let i = 0; i < updated.length; i++)
            updated[i] = { display: updated[i].display,
                           current: Math.round(clamped * updated[i].max),
                           max: updated[i].max }
        monitors = updated
        brightnessAdjusted(clamped)
        _setPending = Math.round(clamped * 100)
        _setIndex = 0
        _doSetNext()
    }

    function _doSetNext() {
        if (_setIndex >= monitors.length || setProc.running) return
        setProc.command = ["ddcutil", "setvcp", "10", String(_setPending),
                           "--display", String(monitors[_setIndex].display)]
        setProc.running = true
    }

    function increase(step) { setBrightness(brightness + (step || 0.05)) }
    function decrease(step) { setBrightness(brightness - (step || 0.05)) }
}
