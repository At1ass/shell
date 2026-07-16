pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

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
                // activeToplevel.title is updated by Quickshell before the event fires
                const tl = Hyprland.activeToplevel
                if (tl) root.windowTitle = tl.title ?? ""
            }
        }
    }

    Component.onCompleted: {
        const tl = Hyprland.activeToplevel
        if (tl) {
            root.windowTitle = tl.title ?? ""
            root.windowClass = tl.lastIpcObject.class ?? ""
        }
    }
}
