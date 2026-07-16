pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

// Event-driven refresh of Quickshell's Hyprland data (workspaces, monitors,
// toplevels). Without explicit refresh calls on raw events the data goes
// stale; every consumer of Hyprland.workspaces/toplevels depends on this
// singleton being alive. shell.qml calls init() once at startup.
Singleton {
    id: root

    // Side-effect singletons instantiate on first reference; init() is that
    // reference, called from shell.qml. Deliberately empty.
    function init() {}

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            const n = event.name
            if (n.endsWith("v2"))
                return

            if (["workspace", "moveworkspace", "activespecial", "focusedmon"].includes(n)) {
                Hyprland.refreshWorkspaces()
                Hyprland.refreshMonitors()
            } else if (["openwindow", "closewindow", "movewindow", "exec"].includes(n)) {
                Hyprland.refreshToplevels()
                Hyprland.refreshWorkspaces()
            } else if (n.includes("mon")) {
                Hyprland.refreshMonitors()
            } else if (n.includes("workspace")) {
                Hyprland.refreshWorkspaces()
            } else if (n.includes("window") || n.includes("group") || ["pin", "fullscreen", "changefloatingmode", "minimize"].includes(n)) {
                Hyprland.refreshToplevels()
            }
        }
    }
}
