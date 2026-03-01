pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var sessions: []
    property int selectedIndex: 0

    readonly property var currentSession: sessions.length > 0 ? sessions[selectedIndex] : null

    function selectNext() {
        if (sessions.length > 0)
            selectedIndex = (selectedIndex + 1) % sessions.length
    }

    function selectPrevious() {
        if (sessions.length > 0)
            selectedIndex = (selectedIndex - 1 + sessions.length) % sessions.length
    }

    Process {
        id: scanner
        command: ["bash", "-c",
            "for f in /usr/share/wayland-sessions/*.desktop /usr/share/xsessions/*.desktop; do " +
            "[ -f \"$f\" ] && echo \"---FILE---\" && cat \"$f\"; done"
        ]
        running: true

        stdout: SplitParser {
            onRead: data => {
                root._rawOutput += data + "\n"
            }
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                console.warn("SessionModel: session scan failed with code", exitCode)
            }
            root._parseOutput()
        }
    }

    property string _rawOutput: ""

    function _parseOutput() {
        let result = []
        let blocks = _rawOutput.split("---FILE---")

        for (let i = 0; i < blocks.length; i++) {
            let block = blocks[i].trim()
            if (!block) continue

            let name = ""
            let exec = ""
            let comment = ""

            let lines = block.split("\n")
            for (let j = 0; j < lines.length; j++) {
                let line = lines[j].trim()
                // Only match exact keys (not localized variants like Name[ru])
                if (line.match(/^Name=/) && !name)
                    name = line.substring(5)
                else if (line.match(/^Exec=/) && !exec)
                    exec = line.substring(5)
                else if (line.match(/^Comment=/) && !comment)
                    comment = line.substring(8)
            }

            if (name && exec) {
                result.push({ name: name, exec: exec, comment: comment })
            }
        }

        root.sessions = result

        // Auto-select default session from config
        if (GreeterConfig.defaultSession && result.length > 0) {
            let defaultLower = GreeterConfig.defaultSession.toLowerCase()
            for (let k = 0; k < result.length; k++) {
                if (result[k].name.toLowerCase() === defaultLower ||
                    result[k].exec.toLowerCase().indexOf(defaultLower) !== -1) {
                    root.selectedIndex = k
                    break
                }
            }
        }
    }
}
