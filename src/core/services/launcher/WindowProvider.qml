import QtQuick
import Quickshell.Hyprland
import FuzzySearch
import qs.src.core.config
import qs.src.core.services
import "../WindowWorkspace.js" as WindowWorkspace

BaseProvider {
    id: root
    name: "Open windows"
    priority: 70
    prefixes: ["@"]
    readonly property var entries: GlobalStates.launcherOpen && LauncherService.mode === "windows"
        ? Array.from(Hyprland.toplevels.values ?? []).filter(window=>!!window?.address).map(window=>{
            const app=window.lastIpcObject?.class || ""
            const appName=IconCategoryResolver.appName(app)
            const workspace=WindowWorkspace.id(window)
            return {address:window.address,title:window.title || appName,app:appName,workspace:workspace,
                icon:DockService.resolveEntry(app)?.icon || "application-x-executable"}
        }) : []
    onEntriesChanged: Qt.callLater(invalidateVisible)
    function invalidateVisible() {
        if (GlobalStates.launcherOpen && LauncherService.mode === "windows") resultsInvalidated()
    }
    function focus(address) {
        if (GlobalStates.lockscreenActive || !AppConfig.moduleEnabled("launcher")) return false
        // The launcher is already unloaded here. Resolve the live global model,
        // not a cached row or a workspace's potentially delayed child model.
        const window=Array.from(Hyprland.toplevels.values ?? []).find(item=>item.address===address)
        if (!window) return false
        HyprlandDispatch.focusWindow(address)
        return true
    }
    function search(query) {
        const text=removePrefix(query).trim()
        const hits=text ? FuzzySearch.matchWeighted(text,entries.map(item=>item.title),
            entries.map(item=>item.app+" "+item.title+" "+(item.workspace ?? "")),50,35,2.5)
            : entries.map((item,index)=>({index:index,score:0}))
        return hits.map(hit=>{
            const entry=entries[hit.index]
            return {id:"window:"+entry.address,type:"window",text:entry.title,
                description:entry.app+" · "+(Number.isInteger(entry.workspace) ? entry.workspace<0 ? "Special workspace" : "Workspace "+entry.workspace : "Workspace unavailable"),icon:entry.icon,score:hit.score,
                action:()=>root.focus(entry.address)}
        })
    }
}
