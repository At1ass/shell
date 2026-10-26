pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Resolve a concrete session object before subscribing. Never accept an
// Unlock signal belonging to another session of this or any other user.
Singleton {
    id: root
    signal lockRequested()
    signal unlockRequested()
    signal resumed()
    property string _resolvedPath: ""
    property bool _resolveExited: false
    property bool _resolveOutputReady: false
    property int _resolveExitCode: -1

    Process {
        id: resolveProc
        command: ["gdbus", "call", "--system", "--dest", "org.freedesktop.login1",
                  "--object-path", "/org/freedesktop/login1",
                  "--method", "org.freedesktop.login1.Manager.GetSession",
                  Quickshell.env("XDG_SESSION_ID") || "auto"]
        stdout: StdioCollector {
            onStreamFinished: {
                const match = text.match(/'(\/org\/freedesktop\/login1\/session\/[A-Za-z0-9_]+)'/)
                root._resolvedPath = match ? match[1] : ""
                root._resolveOutputReady = true
                root._startMonitorIfReady()
            }
        }
        onStarted: resolveTimeout.restart()
        onExited: exitCode => {
            resolveTimeout.stop()
            root._resolveExitCode = exitCode
            root._resolveExited = true
            root._startMonitorIfReady()
        }
    }
    Process {
        id: monitorProc
        stdout: SplitParser {
            onRead: line => {
                if (/^\/org\/freedesktop\/login1:\s+org\.freedesktop\.login1\.Manager\.PrepareForSleep \(\s*false\s*,?\s*\)$/.test(line.trim())) {
                    root.resumed()
                    return
                }
                // Session events still require our exact resolved object path.
                if (!line.startsWith(root._resolvedPath + ":")) return
                if (line.includes("org.freedesktop.login1.Session.Lock ()")) root.lockRequested()
                else if (line.includes("org.freedesktop.login1.Session.Unlock ()")) root.unlockRequested()
            }
        }
        onExited: retry.restart()
    }
    Timer {
        id: resolveTimeout
        interval: 3000
        onTriggered: if (resolveProc.running) resolveProc.signal(9)
    }
    Timer {
        id: retry
        interval: 2000
        onTriggered: root._resolve()
    }
    function _startMonitorIfReady() {
        if (!root._resolveExited) return
        if (root._resolveExitCode !== 0) {
            retry.restart()
            return
        }
        if (!root._resolveOutputReady) return
        if (root._resolvedPath === "") {
            retry.restart()
            return
        }
        if (monitorProc.running) return
        monitorProc.command = ["gdbus", "monitor", "--system",
                               "--dest", "org.freedesktop.login1"]
        monitorProc.running = true
    }

    function _resolve() {
        if (resolveProc.running || monitorProc.running) return
        root._resolvedPath = ""
        root._resolveExited = false
        root._resolveOutputReady = false
        root._resolveExitCode = -1
        resolveProc.running = true
    }
    Component.onCompleted: root._resolve()
}
