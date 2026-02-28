pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Singleton {
    id: root

    property string currentLayoutName: ""
    property string currentLayoutCode: ""
    property var layoutCodes: []
    property var cachedLayoutCodes: ({})
    property bool capsLockEnabled: false
    property bool numLockEnabled: false

    // Fetch keyboard devices from Hyprland
    Process {
        id: fetchLayoutsProcess
        command: ["hyprctl", "-j", "devices"]

        stdout: StdioCollector {
            id: devicesCollector
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(devicesCollector.text)
                    const kb = parsed["keyboards"].find(k => k.main === true)
                    if (kb) {
                        root.layoutCodes = kb["layout"].split(",")
                        root.currentLayoutName = kb["active_keymap"]
                        root.capsLockEnabled = kb["capsLock"] || false
                        root.numLockEnabled = kb["numLock"] || false
                    }
                } catch (e) {
                    console.warn("KeyboardLayoutService: failed to parse devices:", e)
                }
            }
        }
    }

    // Resolve layout name → short code via xkb base.lst
    Process {
        id: getLayoutCodeProcess
        command: ["cat", "/usr/share/X11/xkb/rules/base.lst"]

        stdout: StdioCollector {
            id: layoutCollector
            onStreamFinished: {
                const lines = layoutCollector.text.split("\n")
                const target = root.currentLayoutName
                lines.find(line => {
                    if (!line.trim() || line.trim().startsWith('!')) return false

                    const m = line.match(/^\s*(\S+)\s+(.+)$/)
                    if (m && m[2] === target) {
                        root.cachedLayoutCodes[m[2]] = m[1]
                        root.currentLayoutCode = m[1]
                        return true
                    }

                    const mv = line.match(/^\s*(\S+)\s+(\S+)\s+(.+)$/)
                    if (mv && mv[3] === target) {
                        root.cachedLayoutCodes[mv[3]] = mv[2] + mv[1]
                        root.currentLayoutCode = mv[2] + mv[1]
                        return true
                    }
                    return false
                })
            }
        }
    }

    // Layout switch process
    Process {
        id: switchProcess
    }

    // Listen for layout changes from Hyprland
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activelayout") {
                root.currentLayoutName = event.data.split(",")[1]
            }
        }
    }

    // Periodic polling for CapsLock/NumLock state
    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: false
        onTriggered: {
            if (!fetchLayoutsProcess.running)
                fetchLayoutsProcess.running = true
        }
    }

    onCurrentLayoutNameChanged: _updateLayoutCode()

    function _updateLayoutCode() {
        if (cachedLayoutCodes.hasOwnProperty(currentLayoutName)) {
            currentLayoutCode = cachedLayoutCodes[currentLayoutName]
        } else if (!getLayoutCodeProcess.running) {
            getLayoutCodeProcess.running = true
        }
    }

    function switchLayout() {
        if (layoutCodes.length <= 1) return
        if (!switchProcess.running) {
            switchProcess.command = ["hyprctl", "switchxkblayout", "main", "next"]
            switchProcess.running = true
        }
    }

    Component.onCompleted: {
        if (!fetchLayoutsProcess.running)
            fetchLayoutsProcess.running = true
    }
}
