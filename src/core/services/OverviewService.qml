pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell as QS
import Quickshell.Hyprland
import Quickshell.Wayland
import FuzzySearch
import qs.src.core.config

Singleton {
    id: root
    readonly property bool active: GlobalStates.overviewOpen
    property string query: ""
    // The generic toplevel manager supplies capture handles, as in DockService.
    // Referencing only the Hyprland mapping handle is insufficient for capture.
    readonly property QS.ObjectModel _captureHandles: active && AppConfig.overviewShowPreviews ? ToplevelManager.toplevels as QS.ObjectModel : null
    readonly property QS.ObjectModel _windows: Hyprland.toplevels as QS.ObjectModel
    readonly property QS.ObjectModel _workspaces: Hyprland.workspaces as QS.ObjectModel
    readonly property list<HyprlandToplevel> windows: active ? Array.from(_windows?.values ?? []) : []
    readonly property var byAddress: {
        const result = Object.create(null)
        for (const window of windows) if (window?.address) result[window.address] = window
        return result
    }
    readonly property var workspaces: {
        if (!active) return []
        const result = Object.create(null)
        for (let i = 0; i < AppConfig.overviewWorkspaceCount; i++) {
            const id = AppConfig.overviewFirstWorkspace + i
            result[id] = {id:id, name:String(id), native:null}
        }
        for (const workspace of Array.from(_workspaces?.values ?? [])) {
            if (!workspace || Math.abs(workspace.id) >= 100000 || workspace.id === 0) continue
            if (workspace.name.startsWith("special:") && !AppConfig.overviewIncludeSpecial) continue
            result[workspace.id] = {id:workspace.id,name:workspace.name || String(workspace.id),native:workspace}
        }
        return Object.values(result).sort((a,b) => (a.id < 0) - (b.id < 0) || a.id-b.id)
    }
    readonly property var workspaceIds: {
        const ids = Object.create(null)
        for (const workspace of workspaces) ids[workspace.id] = true
        return ids
    }
    readonly property list<string> matches: {
        const candidates = windows.filter(window => !!window?.address && workspaceIds[window.workspace?.id])
        if (!query.trim()) return candidates.map(window => window.address)
        const labels = candidates.map(window => (window.title || "") + " " + (window.lastIpcObject.class || "") + " " + (window.workspace?.name || ""))
        return FuzzySearch.match(query.trim(), labels, candidates.length, 65).map(hit => candidates[hit.index].address)
    }
    function windowFor(address) { return byAddress[address] ?? null }
    function focusWindow(address) {
        if (!windowFor(address)) return false
        GlobalStates.closePanel("overview")
        HyprlandDispatch.focusWindow(address)
        return true
    }
    function focusWorkspace(id) {
        const target = workspaces.find(workspace => workspace.id === id)
        if (!target) return false
        GlobalStates.closePanel("overview")
        HyprlandDispatch.focusWorkspace(target.id, target.name)
        return true
    }
    function moveWindow(address, id) {
        const window = windowFor(address)
        const target = workspaces.find(workspace => workspace.id === id)
        if (!window || !target || window.workspace?.id === id) return false
        HyprlandDispatch.moveWindowToWorkspace(address, target.id, target.name)
        return true
    }
    function refresh() {
        if (!active) return
        Hyprland.refreshToplevels()
        Hyprland.refreshWorkspaces()
    }
    onActiveChanged: { if (!active) query = ""; else refresh() }
    Component.onCompleted: refresh()
}
