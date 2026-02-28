pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Singleton {
    id: root

    property string windowTitle: ""
    property string windowClass: ""

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activewindow") {
                const sep = event.data.indexOf(",")
                root.windowClass = sep >= 0 ? event.data.substring(0, sep) : ""
                root.windowTitle = sep >= 0 ? event.data.substring(sep + 1) : ""
            } else if (event.name === "windowtitle") {
                if (!refetchProc.running)
                    refetchProc.running = true
            }
        }
    }

    Process {
        id: refetchProc
        command: ["hyprctl", "-j", "activewindow"]

        stdout: StdioCollector {
            id: refetchCollector
            onStreamFinished: {
                try {
                    const obj = JSON.parse(refetchCollector.text)
                    root.windowTitle = obj.title ?? ""
                    root.windowClass = obj.class ?? root.windowClass
                } catch (e) {
                    console.warn("ActiveWindowService: failed to parse active window:", e)
                }
            }
        }
    }

    Component.onCompleted: {
        if (!refetchProc.running)
            refetchProc.running = true
    }
}
