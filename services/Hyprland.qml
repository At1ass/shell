pragma Singleton

import Quickshell
import Quickshell.Hyprland
import QtQuick

Singleton {
    id: root

    // Expose Hyprland API
    readonly property var toplevels: Hyprland.toplevels
    readonly property var workspaces: Hyprland.workspaces
    readonly property var monitors: Hyprland.monitors

    readonly property HyprlandToplevel activeToplevel: Hyprland.activeToplevel?.wayland?.activated ? Hyprland.activeToplevel : null
    readonly property HyprlandWorkspace focusedWorkspace: Hyprland.focusedWorkspace
    readonly property HyprlandMonitor focusedMonitor: Hyprland.focusedMonitor
    readonly property int activeWsId: focusedWorkspace?.id ?? 1

    // Computed properties
    readonly property var occupiedWorkspaces: getOccupiedWorkspaces()

    function getOccupiedWorkspaces() {
        let result = {}
        const toplevels = Hyprland.toplevels?.values || []

        for (let i = 1; i <= 9; i++) {
            const windowsOnWs = toplevels.filter(c => c.workspace?.id === i)
            result[i] = windowsOnWs.length > 0
        }
        return result
    }

    function dispatch(request: string) {
        Hyprland.dispatch(request)
    }

    function monitorFor(screen) {
        return Hyprland.monitorFor(screen)
    }

    function switchWorkspace(id) {
        dispatch(`workspace ${id}`)
    }

    function closeWindow() {
        dispatch("killactive")
    }

    // Handle Hyprland events and refresh data accordingly
    Connections {
        target: Hyprland

        function onRawEvent(event) {
            const n = event.name
            if (n.endsWith("v2")) return

            if (["workspace", "moveworkspace", "activespecial", "focusedmon"].includes(n)) {
                Hyprland.refreshWorkspaces()
                Hyprland.refreshMonitors()
            } else if (["openwindow", "closewindow", "movewindow"].includes(n)) {
                Hyprland.refreshToplevels()
                Hyprland.refreshWorkspaces()
                // Trigger recomputation of occupied workspaces
                root.occupiedWorkspacesChanged()
            } else if (n.includes("workspace")) {
                Hyprland.refreshWorkspaces()
            } else if (n.includes("window") || n.includes("group") || ["pin", "fullscreen", "changefloatingmode", "minimize"].includes(n)) {
                Hyprland.refreshToplevels()
                root.occupiedWorkspacesChanged()
            }
        }
    }
}