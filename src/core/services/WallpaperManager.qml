pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.src.core.config
import qs.src.core.services
import qs.src.core.services.wallpaper

// WallpaperManager — orchestrator for the wallpaper subsystem.
//
// Responsibilities:
//   - Binds each monitor to a source from WallpaperSourceRegistry and
//     remembers per-monitor cycling state (current item, fill mode,
//     auto-change settings, random vs sequential).
//   - Listens for source.itemsRefreshed and applies the bound monitor's
//     current item once items become available.
//   - Drives auto-change via a single global ticker that walks
//     monitorBindings and steps any monitor whose interval elapsed.
//   - Persists per-monitor state (sourceId + currentItemId) via
//     AppConfig stateData on every applied change.
//   - Runs the post-set script with (monitor, path) per spec.
//   - Exposes the legacy IPC interface (target: "wallpaper") so existing
//     keybindings/scripts keep working.

Singleton {
    id: manager

    // ── Configuration (from AppConfig) ───────────────────────────────
    readonly property string primaryMonitor: AppConfig.wallpaperPrimaryMonitor
    readonly property string defaultWallpaperPath: AppConfig.wallpaperDefaultPath
    readonly property string postSetScriptPath: AppConfig.wallpaperPostScript

    // ── Public state ─────────────────────────────────────────────────

    // Per-monitor binding:
    //   {
    //     sourceId: string,
    //     currentItemId: string,
    //     currentItemIndex: int,
    //     fillMode: int,           // Image.fillMode value
    //     randomOrder: bool,
    //     autoChange: { enabled: bool, intervalMs: int },
    //     lastChangeMs: real
    //   }
    property var monitorBindings: ({})

    // Per-monitor resolved wallpaper URL (consumer-facing).
    property var monitorWallpapers: ({})

    // Used by Theme.qml for color extraction.
    readonly property url currentWallpaper:
        monitorWallpapers[primaryMonitor] || _asUrl(defaultWallpaperPath)

    // ── Internal ─────────────────────────────────────────────────────
    property bool _initialized: false
    property bool _stateApplied: false
    property var  _connectedSources: ({})  // sourceId → true; tracks which sources we've subscribed to

    Component.onCompleted: {
        if (AppConfig.ready) initFromConfig()
    }

    Connections {
        target: AppConfig
        function onReadyChanged() {
            if (AppConfig.ready && !manager._initialized) initFromConfig()
        }
        function onDataChanged() {
            if (manager._initialized) initFromConfig()
        }
        function onStateDataChanged() {
            if (manager._initialized && !manager._stateApplied) loadState()
        }
    }

    Connections {
        target: WallpaperSourceRegistry
        function onSourcesChanged() { manager._wireSources() }
    }

    // Single global ticker for auto-change. Each tick scans monitorBindings
    // and steps any monitor whose elapsed time exceeds intervalMs.
    Timer {
        interval: 1000
        running: !(GamingModeService.gamingModeActive && AppConfig.gmDisableWallpaperChange)
        repeat: true
        onTriggered: manager._autoChangeTick()
    }

    // ── Init / config apply ──────────────────────────────────────────

    function initFromConfig() {
        const wp = AppConfig.data.wallpaper || {}
        const monitorsConf = wp.monitors || {}

        const newBindings = {}
        for (const mon in monitorsConf) {
            const c = monitorsConf[mon] || {}
            newBindings[mon] = {
                "sourceId":         c.sourceId || "",
                "currentItemId":    "",
                "currentItemIndex": 0,
                "fillMode":         c.fillMode !== undefined ? c.fillMode : Image.PreserveAspectCrop,
                "randomOrder":      c.randomOrder !== false,
                "autoChange": {
                    "enabled":    c.autoChange?.enabled === true,
                    "intervalMs": c.autoChange?.intervalMs ?? 300000
                },
                "lastChangeMs": 0
            }
        }
        monitorBindings = newBindings

        // Initial wallpapers default to the static defaultWallpaperPath
        // until source items arrive (then _applyForMonitor takes over).
        const baseUrl = _asUrl(defaultWallpaperPath)
        const newWallpapers = {}
        for (const mon in newBindings) newWallpapers[mon] = baseUrl
        monitorWallpapers = newWallpapers

        _initialized = true
        _wireSources()

        // Try applying — sources may already have items if they were
        // ready before we initialized.
        for (const mon in newBindings) _applyForMonitor(mon)

        loadState()
    }

    function _wireSources() {
        for (const id of WallpaperSourceRegistry.sourceIds) {
            if (_connectedSources[id]) continue
            const source = WallpaperSourceRegistry.getSource(id)
            if (!source) continue
            source.itemsRefreshed.connect(() => manager._onSourceItemsRefreshed(id))
            const updated = Object.assign({}, _connectedSources)
            updated[id] = true
            _connectedSources = updated
        }
        // Drop refs to removed sources so re-wire fires next time
        const stillExists = {}
        for (const id of WallpaperSourceRegistry.sourceIds) stillExists[id] = true
        const cleaned = {}
        for (const id in _connectedSources) if (stillExists[id]) cleaned[id] = true
        _connectedSources = cleaned
    }

    function _onSourceItemsRefreshed(sourceId) {
        for (const mon in monitorBindings) {
            if (monitorBindings[mon].sourceId === sourceId) _applyForMonitor(mon)
        }
    }

    // ── State persistence ───────────────────────────────────────────

    function loadState() {
        const state = AppConfig.wallpaperState
        if (!state || !state.monitors) {
            _stateApplied = true
            return
        }

        const bindings = Object.assign({}, monitorBindings)
        let dirty = false

        for (const mon in state.monitors) {
            const ms = state.monitors[mon] || {}
            if (!bindings[mon]) bindings[mon] = _defaultBinding()
            // Saved sourceId overrides config only if config didn't specify it
            if (!bindings[mon].sourceId && ms.sourceId) {
                bindings[mon].sourceId = ms.sourceId
                dirty = true
            }
            if (ms.currentItemId) {
                bindings[mon].currentItemId = ms.currentItemId
                dirty = true
            }
        }
        if (dirty) {
            monitorBindings = bindings
            for (const mon in bindings) _applyForMonitor(mon)
        }
        _stateApplied = true
    }

    function saveState() {
        const state = { "monitors": {} }
        for (const mon in monitorBindings) {
            const b = monitorBindings[mon]
            state.monitors[mon] = {
                "sourceId":      b.sourceId || "",
                "currentItemId": b.currentItemId || ""
            }
        }
        AppConfig.updateState("wallpaper", state)
    }

    function _defaultBinding() {
        return {
            "sourceId": "", "currentItemId": "", "currentItemIndex": 0,
            "fillMode": Image.PreserveAspectCrop,
            "randomOrder": true,
            "autoChange": { "enabled": false, "intervalMs": 300000 },
            "lastChangeMs": 0
        }
    }

    // ── Cycling logic ───────────────────────────────────────────────

    function _applyForMonitor(monitor) {
        const b = monitorBindings[monitor]
        if (!b || !b.sourceId) return
        const source = WallpaperSourceRegistry.getSource(b.sourceId)
        if (!source || !source.items.length) return

        let item
        if (b.currentItemId) {
            item = source.findItem(b.currentItemId)
            if (item) {
                _applyItem(monitor, source, item)
                return
            }
        }
        // No saved item — pick first/random
        const idx = b.randomOrder
            ? Math.floor(Math.random() * source.items.length)
            : 0
        b.currentItemIndex = idx
        b.currentItemId = source.items[idx].id
        monitorBindings = Object.assign({}, monitorBindings)
        _applyItem(monitor, source, source.items[idx])
    }

    function _stepMonitor(monitor, step, persist) {
        const b = monitorBindings[monitor]
        if (!b) return
        const source = WallpaperSourceRegistry.getSource(b.sourceId)
        if (!source || !source.items.length) return

        let nextIdx
        if (b.randomOrder) {
            nextIdx = Math.floor(Math.random() * source.items.length)
        } else {
            const cur = b.currentItemIndex !== undefined ? b.currentItemIndex : 0
            nextIdx = (cur + step + source.items.length) % source.items.length
        }
        const item = source.items[nextIdx]
        b.currentItemIndex = nextIdx
        b.currentItemId = item.id
        b.lastChangeMs = Date.now()
        monitorBindings = Object.assign({}, monitorBindings)
        _applyItem(monitor, source, item)
        if (persist) saveState()
    }

    function _applyItem(monitor, source, item) {
        const url = source.resolveItem(item.id)
        if (!url || url.length === 0) return  // remote async — Stage D adds itemResolved

        const wallpapers = Object.assign({}, monitorWallpapers)
        wallpapers[monitor] = _asUrl(url)
        monitorWallpapers = wallpapers
        _schedulePostScript(monitor, url)
    }

    function _autoChangeTick() {
        const now = Date.now()
        let changed = false
        for (const mon in monitorBindings) {
            const b = monitorBindings[mon]
            if (!b.autoChange?.enabled) continue
            if (b.lastChangeMs === 0) {
                b.lastChangeMs = now
                changed = true
                continue
            }
            if (now - b.lastChangeMs >= b.autoChange.intervalMs) {
                _stepMonitor(mon, 1, true)
                changed = true
            }
        }
        if (changed) monitorBindings = Object.assign({}, monitorBindings)
    }

    // ── Public API ──────────────────────────────────────────────────

    function getWallpaper(monitor) {
        return monitorWallpapers[monitor] || _asUrl(defaultWallpaperPath)
    }

    function getFillMode(monitor) {
        const b = monitorBindings[monitor]
        return b ? b.fillMode : Image.PreserveAspectCrop
    }

    function nextWallpaper(monitor, persist) {
        if (persist === undefined) persist = true
        if (monitor && monitor.length > 0) {
            _stepMonitor(monitor, 1, persist)
        } else {
            for (const mon in monitorBindings) _stepMonitor(mon, 1, persist)
        }
    }

    function previousWallpaper(monitor, persist) {
        if (persist === undefined) persist = true
        if (monitor && monitor.length > 0) {
            _stepMonitor(monitor, -1, persist)
        } else {
            for (const mon in monitorBindings) _stepMonitor(mon, -1, persist)
        }
    }

    function setMonitorSource(monitor, sourceId) {
        if (!monitorBindings[monitor]) monitorBindings[monitor] = _defaultBinding()
        monitorBindings[monitor].sourceId = sourceId
        monitorBindings[monitor].currentItemId = ""
        monitorBindings = Object.assign({}, monitorBindings)
        _applyForMonitor(monitor)
        saveState()
    }

    // Set wallpaper directly — bypasses source machinery. Useful for
    // ad-hoc IPC setting from a script.
    function setWallpaper(monitor, path, persist) {
        if (!monitor || monitor.length === 0) return
        if (persist === undefined) persist = true
        const wallpapers = Object.assign({}, monitorWallpapers)
        wallpapers[monitor] = _asUrl(path)
        monitorWallpapers = wallpapers
        _schedulePostScript(monitor, path)
        if (persist) saveState()
    }

    function setAllMonitorsWallpaper(path, persist) {
        if (persist === undefined) persist = true
        const url = _asUrl(path)
        const wallpapers = {}
        for (const mon in monitorBindings) wallpapers[mon] = url
        monitorWallpapers = wallpapers
        for (const mon in monitorBindings) _schedulePostScript(mon, path)
        if (persist) saveState()
    }

    function setFillMode(monitor, fillMode) {
        if (!monitorBindings[monitor]) monitorBindings[monitor] = _defaultBinding()
        monitorBindings[monitor].fillMode = fillMode
        monitorBindings = Object.assign({}, monitorBindings)
    }

    function setAllMonitorsFillMode(fillMode) {
        for (const mon in monitorBindings) monitorBindings[mon].fillMode = fillMode
        monitorBindings = Object.assign({}, monitorBindings)
    }

    // ── Post-script ─────────────────────────────────────────────────

    property var _postScriptQueue: []

    Process {
        id: postScriptProcess
        onExited: manager._runNextPostScript()
        stdout: StdioCollector {}
        stderr: StdioCollector {
            onStreamFinished: {
                const err = text.trim()
                if (err) ToastService.warning("Wallpaper post-script: " + err)
            }
        }
    }

    function _schedulePostScript(monitor, path) {
        if (!postSetScriptPath || postSetScriptPath.length === 0) return

        manager._postScriptQueue.push({
            "monitor": monitor || "",
            "path":    _normalizeFilesystemPath(path)
        })
        if (!postScriptProcess.running) _runNextPostScript()
    }

    function _runNextPostScript() {
        if (!_postScriptQueue.length) {
            _postScriptQueue = []
            return
        }
        const next = _postScriptQueue.shift()
        const cmd = _buildShellCommand(postSetScriptPath, next.monitor, next.path)
        if (!cmd) {
            _runNextPostScript()
            return
        }
        postScriptProcess.command = ["bash", "-lc", cmd]
        postScriptProcess.running = true
    }

    function _buildShellCommand(scriptPath, monitor, path) {
        const trimmed = scriptPath.trim()
        if (!trimmed) return ""
        return `${_escapeShellArg(trimmed)} ${_escapeShellArg(monitor || "")} ${_escapeShellArg(path || "")}`
    }

    function _escapeShellArg(input) {
        if (input === undefined || input === null) return "''"
        const s = String(input)
        if (!s) return "''"
        return `'${s.replace(/'/g, `'\\''`)}'`
    }

    function _normalizeFilesystemPath(path) {
        if (!path) return ""
        const s = String(path)
        if (!s) return ""
        if (s.startsWith("file://")) return s.substring(7)
        return s
    }

    function _asUrl(path) {
        if (!path || path.length === 0) return ""
        if (path.startsWith("file://")) return path
        return Qt.resolvedUrl(path)
    }

    // ── IPC (target stable for keybinding compat) ──────────────────

    IpcHandler {
        target: "wallpaper"

        function set(monitor: string, path: string): string {
            manager.setWallpaper(monitor, path, true)
            return `Wallpaper set for ${monitor}`
        }

        function setAll(path: string): string {
            manager.setAllMonitorsWallpaper(path, true)
            return "Wallpaper set for all monitors"
        }

        function next(monitor: string): string {
            const target = monitor === undefined ? "" : monitor
            manager.nextWallpaper(target, true)
            return target.length > 0
                ? `Switched to next wallpaper on ${target}`
                : "Switched to next wallpaper"
        }

        function previous(monitor: string): string {
            const target = monitor === undefined ? "" : monitor
            manager.previousWallpaper(target, true)
            return target.length > 0
                ? `Switched to previous wallpaper on ${target}`
                : "Switched to previous wallpaper"
        }

        function setSource(monitor: string, sourceId: string): string {
            manager.setMonitorSource(monitor, sourceId)
            return `${monitor} → source ${sourceId}`
        }

        function setFillMode(monitor: string, fillModeValue: string): string {
            manager.setFillMode(monitor, parseInt(fillModeValue))
            return `FillMode set for ${monitor}: ${fillModeValue}`
        }

        function setFillModeAll(fillModeValue: string): string {
            manager.setAllMonitorsFillMode(parseInt(fillModeValue))
            return `FillMode set for all monitors: ${fillModeValue}`
        }

        function setAutoChange(monitor: string, enabled: string, intervalMs: string): string {
            const b = manager.monitorBindings[monitor]
            if (!b) return `No binding for monitor ${monitor}`
            const enable = enabled === "true"
            b.autoChange.enabled = enable
            if (intervalMs) b.autoChange.intervalMs = parseInt(intervalMs)
            manager.monitorBindings = Object.assign({}, manager.monitorBindings)
            return `Auto-change ${enable ? "enabled" : "disabled"} for ${monitor}`
        }

        function status(): string {
            const lines = []
            for (const mon in manager.monitorBindings) {
                const b = manager.monitorBindings[mon]
                lines.push(`${mon}: source=${b.sourceId} item=${b.currentItemId} fill=${b.fillMode} random=${b.randomOrder} auto=${b.autoChange.enabled}/${b.autoChange.intervalMs}ms`)
            }
            return `Sources: ${WallpaperSourceRegistry.sourceIds.join(", ")}
Primary monitor: ${manager.primaryMonitor}
Current wallpaper: ${manager.currentWallpaper}
Monitors:
${lines.join("\n")}`
        }
    }
}
