pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.src.core.config
import qs.src.core.services

Singleton {
    id: wallpaperService

    // ═══════════════════════════════════════════════════════════════
    // CONFIGURATION STATE
    // ═══════════════════════════════════════════════════════════════

    property bool _initialized: false
    property bool _suppressConfigReapply: false
    property bool _stateApplied: false

    property string defaultWallpaperPath: ""
    property string primaryMonitor: ""
    property string postSetScriptPath: ""

    property var configData: ({})
    property var configuredMonitors: []

    property var monitorWallpapers: ({})
    property url currentWallpaper: ""
    property var monitorFillModes: ({})

    property bool directoryMode: false
    property string globalDirectory: ""
    property var monitorDirectories: ({})
    property var monitorFiles: ({})
    property var monitorIndices: ({})
    property var monitorRandomOrder: ({})
    property var postScriptQueue: []

    property bool autoChange: false
    property int changeInterval: 300000
    property bool randomOrder: true

    // ═══════════════════════════════════════════════════════════════
    // INITIALIZATION VIA APPCONFIG
    // ═══════════════════════════════════════════════════════════════

    Component.onCompleted: {
        if (AppConfig.ready) initFromConfig()
    }

    Connections {
        target: AppConfig
        function onReadyChanged() {
            if (AppConfig.ready && !wallpaperService._initialized)
                initFromConfig()
        }
        function onDataChanged() {
            if (wallpaperService._initialized && !wallpaperService._suppressConfigReapply)
                initFromConfig()
            wallpaperService._suppressConfigReapply = false
        }
        function onStateDataChanged() {
            // state.json loaded after initial loadState() — re-apply saved wallpapers
            if (wallpaperService._initialized && !wallpaperService._stateApplied) {
                wallpaperService.loadState()
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // TIMER FOR AUTO-CHANGE
    // ═══════════════════════════════════════════════════════════════

    Timer {
        id: changeTimer
        interval: wallpaperService.changeInterval
        running: wallpaperService.autoChange
                 && wallpaperService.directoryMode
                 && !(GamingModeService.gamingModeActive && AppConfig.gmDisableWallpaperChange)
        repeat: true
        onTriggered: wallpaperService.nextWallpaper(undefined, false)
    }

    // ═══════════════════════════════════════════════════════════════
    // DIRECTORY SCANNING QUEUE
    // ═══════════════════════════════════════════════════════════════

    Process {
        id: scanProcess
        property var queue: []
        property string currentKey: ""
        property string currentDirectory: ""

        stdout: StdioCollector {
            id: scanCollector
            onStreamFinished: wallpaperService.handleScanResult(scanProcess.currentKey, text)
        }

        onExited: wallpaperService.processNextScan()
    }

    // ═══════════════════════════════════════════════════════════════
    // POST-SCRIPT EXECUTION QUEUE
    // ═══════════════════════════════════════════════════════════════

    Process {
        id: postScriptProcess
        onExited: wallpaperService.runNextPostScript()

        stdout: StdioCollector {}

        stderr: StdioCollector {
            onStreamFinished: {
                const err = text.trim()
                if (err) ToastService.warning("Wallpaper post-script: " + err)
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // CONFIGURATION HELPERS
    // ═══════════════════════════════════════════════════════════════

    function initFromConfig() {
        const wp = AppConfig.data.wallpaper || {}
        configData = {
            primaryMonitor: wp.primaryMonitor || "",
            defaultWallpaper: wp.defaultWallpaper || "",
            postSetScript: wp.postSetScript || "",
            global: {
                directory: wp.global?.directory || "",
                randomOrder: wp.global?.randomOrder !== undefined ? wp.global.randomOrder : true,
                autoChange: {
                    enabled: wp.global?.autoChange?.enabled ?? false,
                    intervalMs: wp.global?.autoChange?.intervalMs ?? 300000
                }
            },
            monitors: JSON.parse(JSON.stringify(wp.monitors || {}))
        }
        applyConfigData()
        _initialized = true
    }

    function applyConfigData() {
        defaultWallpaperPath = configData.defaultWallpaper || ""
        randomOrder = !!configData.global.randomOrder

        autoChange = !!configData.global.autoChange.enabled
        changeInterval = configData.global.autoChange.intervalMs || 300000

        primaryMonitor = configData.primaryMonitor || ""
        postSetScriptPath = configData.postSetScript || ""
        configuredMonitors = Object.keys(configData.monitors || {})

        globalDirectory = configData.global.directory || ""

        const newFillModes = {}
        const newWallpapers = {}
        const newDirectories = {}
        const newRandom = {}

        const baseWallpaper = asUrl(defaultWallpaperPath)

        configuredMonitors.forEach(monitor => {
            const monitorCfg = configData.monitors[monitor] || {}
            if (monitorCfg.fillMode !== undefined)
                newFillModes[monitor] = monitorCfg.fillMode

            newWallpapers[monitor] = baseWallpaper

            if (monitorCfg.directory && monitorCfg.directory.length > 0) {
                newDirectories[monitor] = monitorCfg.directory
                if (monitorCfg.randomOrder !== undefined)
                    newRandom[monitor] = monitorCfg.randomOrder
            }
        })

        monitorFillModes = newFillModes
        monitorWallpapers = newWallpapers

        currentWallpaper = newWallpapers[primaryMonitor] || baseWallpaper

        monitorDirectories = newDirectories
        let randomMap = Object.assign({}, newRandom)
        if (globalDirectory.length > 0)
            randomMap["__global"] = randomOrder
        monitorRandomOrder = randomMap

        directoryMode = globalDirectory.length > 0 || Object.keys(monitorDirectories).length > 0

        monitorFiles = ({})
        monitorIndices = ({})

        if (globalDirectory.length > 0)
            enqueueScan("__global", globalDirectory)

        for (let monitor in monitorDirectories)
            enqueueScan(monitor, monitorDirectories[monitor])

        processNextScan()
        loadState()
    }

    function saveConfig() {
        _suppressConfigReapply = true
        AppConfig.updateConfig("wallpaper", configData)
    }

    function saveState() {
        const state = { monitors: {} }
        for (let monitor in monitorWallpapers) {
            const key = filesKeyForMonitor(monitor)
            state.monitors[monitor] = {
                current: normalizeFilesystemPath(monitorWallpapers[monitor]),
                index: key ? (monitorIndices[key] || 0) : 0
            }
        }
        AppConfig.updateState("wallpaper", state)
    }

    function loadState() {
        const state = AppConfig.wallpaperState
        if (!state || !state.monitors) return

        const wallpapers = Object.assign({}, monitorWallpapers)
        const indices = {}
        let wallpapersChanged = false

        for (let monitor in state.monitors) {
            const ms = state.monitors[monitor]
            if (ms.current) {
                wallpapers[monitor] = asUrl(ms.current)
                wallpapersChanged = true
            }
            if (ms.index !== undefined) {
                const key = filesKeyForMonitor(monitor)
                if (key) indices[key] = ms.index
            }
        }

        if (wallpapersChanged) {
            monitorWallpapers = wallpapers
            if (wallpapers[primaryMonitor])
                currentWallpaper = wallpapers[primaryMonitor]
        }
        monitorIndices = indices
        _stateApplied = true
    }

    // ═══════════════════════════════════════════════════════════════
    // DIRECTORY SCANNING HELPERS
    // ═══════════════════════════════════════════════════════════════

    function enqueueScan(key, directory) {
        if (!directory || directory.length === 0)
            return

        scanProcess.queue.push({ key: key, directory: directory })
    }

    function processNextScan() {
        if (scanProcess.running)
            return

        if (!scanProcess.queue || scanProcess.queue.length === 0) {
            scanProcess.currentKey = ""
            scanProcess.currentDirectory = ""
            return
        }

        const next = scanProcess.queue.shift()
        scanProcess.currentKey = next.key
        scanProcess.currentDirectory = next.directory

        scanProcess.command = [
            "find", next.directory,
            "-maxdepth", "1",
            "-type", "f",
            "(",
            "-iname", "*.jpg",
            "-o", "-iname", "*.jpeg",
            "-o", "-iname", "*.png",
            "-o", "-iname", "*.webp",
            ")"
        ]
        scanProcess.running = true
    }

    function handleScanResult(key, rawText) {
        const trimmed = rawText.trim()
        const files = trimmed.length > 0 ? trimmed.split("\n").filter(f => f.length > 0).sort() : []

        const updatedFiles = Object.assign({}, monitorFiles)
        updatedFiles[key] = files
        monitorFiles = updatedFiles

        if (files.length === 0) {
            processNextScan()
            return
        }

        if (key === "__global") {
            configuredMonitors.forEach(monitor => {
                if (!monitorDirectories[monitor])
                    applyDirectoryWallpaper(monitor, key, true)
            })
        } else {
            applyDirectoryWallpaper(key, key, true)
        }

        processNextScan()
    }

    function applyDirectoryWallpaper(monitor, filesKey, initial) {
        const files = monitorFiles[filesKey] || []
        if (files.length === 0)
            return

        let explicit = ""
        if (initial) {
            const state = AppConfig.wallpaperState
            if (state && state.monitors && state.monitors[monitor])
                explicit = state.monitors[monitor].current || ""
        }

        if (initial && explicit.length > 0) {
            const existingIndex = files.indexOf(explicit)
            if (existingIndex >= 0) {
                const updatedIndices = Object.assign({}, monitorIndices)
                updatedIndices[filesKey] = existingIndex
                monitorIndices = updatedIndices
                setWallpaper(monitor, explicit, false)
                return
            }
        }

        const file = selectFileForKey(filesKey, initial ? 0 : 1, initial)
        if (!file)
            return

        let persist = !initial
        if (initial && explicit.length > 0)
            persist = true

        setWallpaper(monitor, file, persist)
    }

    function asUrl(path) {
        if (!path || path.length === 0)
            return ""
        if (path.startsWith("file://"))
            return path
        return Qt.resolvedUrl(path)
    }

    function selectFileForKey(filesKey, step, initial) {
        const files = monitorFiles[filesKey] || []
        if (files.length === 0)
            return null

        const random = monitorRandomOrder[filesKey] !== undefined ? monitorRandomOrder[filesKey] : randomOrder
        const previousIndex = monitorIndices[filesKey]
        let nextIndex = previousIndex !== undefined ? previousIndex : 0

        if (random) {
            nextIndex = Math.floor(Math.random() * files.length)
        } else if (initial) {
            nextIndex = previousIndex !== undefined ? previousIndex : 0
        } else {
            nextIndex = previousIndex !== undefined ? (previousIndex + step + files.length) % files.length : 0
        }

        const updatedIndices = Object.assign({}, monitorIndices)
        updatedIndices[filesKey] = nextIndex
        monitorIndices = updatedIndices

        return files[nextIndex]
    }

    function filesKeyForMonitor(monitor) {
        if (monitorDirectories[monitor])
            return monitor
        if (globalDirectory.length > 0)
            return "__global"
        return ""
    }

    function monitorsWithDirectories() {
        const result = []

        configuredMonitors.forEach(monitor => {
            const key = filesKeyForMonitor(monitor)
            if (key && result.indexOf(monitor) === -1)
                result.push(monitor)
        })

        Object.keys(monitorDirectories).forEach(monitor => {
            if (result.indexOf(monitor) === -1)
                result.push(monitor)
        })

        return result
    }

    function ensureMonitorConfig(monitor) {
        if (!configData.monitors[monitor])
            configData.monitors[monitor] = {}
        configuredMonitors = Object.keys(configData.monitors)
    }

    function knownMonitorKeys() {
        const keys = configuredMonitors.slice()
        for (let monitor in monitorWallpapers) {
            if (keys.indexOf(monitor) === -1)
                keys.push(monitor)
        }
        return keys
    }

    // ═══════════════════════════════════════════════════════════════
    // WALLPAPER MANAGEMENT
    // ═══════════════════════════════════════════════════════════════

    function setWallpaper(monitor, path, persist) {
        if (!monitor || monitor.length === 0)
            return

        const safePath = path || ""
        const resolvedUrl = asUrl(safePath)
        const updated = Object.assign({}, monitorWallpapers)
        updated[monitor] = resolvedUrl
        monitorWallpapers = updated

        if (monitor === primaryMonitor || primaryMonitor.length === 0) {
            currentWallpaper = resolvedUrl
        }

        if (persist === undefined)
            persist = true

        if (persist) {
            saveState()
        }

        schedulePostScript(monitor, safePath)
    }

    function setAllMonitorsWallpaper(path, persist) {
        const safePath = path || ""
        const resolvedUrl = asUrl(safePath)
        const keys = knownMonitorKeys()

        const updated = {}
        keys.forEach(monitor => updated[monitor] = resolvedUrl)
        monitorWallpapers = updated

        currentWallpaper = resolvedUrl

        if (persist === undefined)
            persist = true

        if (persist) {
            saveState()
        }

        keys.forEach(monitor => schedulePostScript(monitor, safePath))
    }

    function setDirectory(monitor, dirPath) {
        if (!dirPath || dirPath.length === 0) {
            console.warn("WallpaperService: empty directory ignored")
            return
        }

        directoryMode = true

        if (!monitor || monitor.length === 0) {
            globalDirectory = dirPath
            configData.global.directory = dirPath
            const updatedRandom = Object.assign({}, monitorRandomOrder)
            updatedRandom["__global"] = randomOrder
            monitorRandomOrder = updatedRandom
            enqueueScan("__global", dirPath)
        } else {
            ensureMonitorConfig(monitor)
            configData.monitors[monitor].directory = dirPath
            const updatedDirectories = Object.assign({}, monitorDirectories)
            updatedDirectories[monitor] = dirPath
            monitorDirectories = updatedDirectories
            enqueueScan(monitor, dirPath)
        }

        saveConfig()
        processNextScan()
    }

    function nextWallpaper(monitor, persist) {
        if (persist === undefined)
            persist = true

        if (monitor && monitor.length > 0) {
            const key = filesKeyForMonitor(monitor)
            if (!key) {
                console.warn(`WallpaperService: no directory for monitor ${monitor}`)
                return
            }

            const file = selectFileForKey(key, 1, false)
            if (!file) {
                console.warn(`WallpaperService: no wallpapers in directory for ${monitor}`)
                return
            }
            setWallpaper(monitor, file, persist)
            return
        }

        monitorsWithDirectories().forEach(name => {
            const key = filesKeyForMonitor(name)
            if (!key)
                return
            const file = selectFileForKey(key, 1, false)
            if (file)
                setWallpaper(name, file, persist)
        })
    }

    function previousWallpaper(monitor, persist) {
        if (persist === undefined)
            persist = true

        if (monitor && monitor.length > 0) {
            const key = filesKeyForMonitor(monitor)
            if (!key) {
                console.warn(`WallpaperService: no directory for monitor ${monitor}`)
                return
            }

            const file = selectFileForKey(key, -1, false)
            if (!file) {
                console.warn(`WallpaperService: no wallpapers in directory for ${monitor}`)
                return
            }
            setWallpaper(monitor, file, persist)
            return
        }

        monitorsWithDirectories().forEach(name => {
            const key = filesKeyForMonitor(name)
            if (!key)
                return
            const file = selectFileForKey(key, -1, false)
            if (file)
                setWallpaper(name, file, persist)
        })
    }

    function setFillMode(monitor, fillMode) {
        const updated = Object.assign({}, monitorFillModes)
        updated[monitor] = fillMode
        monitorFillModes = updated

        ensureMonitorConfig(monitor)
        configData.monitors[monitor].fillMode = fillMode
        saveConfig()
    }

    function setAllMonitorsFillMode(fillMode) {
        const keys = knownMonitorKeys()
        const updated = {}
        keys.forEach(monitor => updated[monitor] = fillMode)
        monitorFillModes = updated

        keys.forEach(monitor => {
            ensureMonitorConfig(monitor)
            configData.monitors[monitor].fillMode = fillMode
        })
        saveConfig()
    }

    function getWallpaper(monitor) {
        return monitorWallpapers[monitor] || currentWallpaper || asUrl(defaultWallpaperPath)
    }

    function getFillMode(monitor) {
        return monitorFillModes[monitor] !== undefined ? monitorFillModes[monitor] : Image.PreserveAspectCrop
    }

    function schedulePostScript(monitor, path) {
        if (!postSetScriptPath || postSetScriptPath.length === 0)
            return

        const actualMonitor = monitor || ""
        const actualPath = normalizeFilesystemPath(path)

        postScriptQueue.push({
            monitor: actualMonitor,
            path: actualPath
        })

        if (!postScriptProcess.running)
            runNextPostScript()
    }

    function runNextPostScript() {
        if (!postScriptQueue || postScriptQueue.length === 0) {
            postScriptQueue = []
            return
        }

        const next = postScriptQueue.shift()
        const scriptCommand = buildShellCommand(postSetScriptPath, next.monitor, next.path)

        if (!scriptCommand || scriptCommand.length === 0) {
            console.warn("WallpaperService: unable to build command for post-set script")
            runNextPostScript()
            return
        }

        postScriptProcess.command = ["bash", "-lc", scriptCommand]
        postScriptProcess.running = true
    }

    function buildShellCommand(scriptPath, monitor, path) {
        const trimmedScript = scriptPath.trim()
        if (trimmedScript.length === 0)
            return ""

        const escapedScript = escapeShellArg(trimmedScript)
        const escapedMonitor = escapeShellArg(monitor || "")
        const escapedPath = escapeShellArg(path || "")
        return `${escapedScript} ${escapedMonitor} ${escapedPath}`
    }

    function escapeShellArg(input) {
        if (input === undefined || input === null)
            return "''"
        const str = String(input)
        if (str.length === 0)
            return "''"
        return `'${str.replace(/'/g, `'\\''`)}'`
    }

    function normalizeFilesystemPath(path) {
        if (!path)
            return ""

        const str = String(path)
        if (str.length === 0)
            return ""

        if (str.startsWith("file://"))
            return str.substring(7)

        return str
    }

    // ═══════════════════════════════════════════════════════════════
    // IPC HANDLER
    // ═══════════════════════════════════════════════════════════════

    IpcHandler {
        target: "wallpaper"

        function set(monitor: string, path: string): string {
            wallpaperService.setWallpaper(monitor, path)
            return `Wallpaper set for ${monitor}`
        }

        function setAll(path: string): string {
            wallpaperService.setAllMonitorsWallpaper(path)
            return "Wallpaper set for all monitors"
        }

        function setDirectory(monitorOrDir: string, dirPath: string): string {
            if (dirPath === undefined || dirPath.length === 0) {
                wallpaperService.setDirectory("", monitorOrDir)
                return `Global directory set: ${monitorOrDir}`
            }

            wallpaperService.setDirectory(monitorOrDir, dirPath)
            return `Directory set for ${monitorOrDir}: ${dirPath}`
        }

        function next(monitor: string): string {
            const target = monitor === undefined ? "" : monitor
            wallpaperService.nextWallpaper(target || "", true)
            return target && target.length > 0 ? `Switched to next wallpaper on ${target}` : "Switched to next wallpaper"
        }

        function previous(monitor: string): string {
            const target = monitor === undefined ? "" : monitor
            wallpaperService.previousWallpaper(target || "", true)
            return target && target.length > 0 ? `Switched to previous wallpaper on ${target}` : "Switched to previous wallpaper"
        }

        function setAutoChange(enabled: string, intervalMs: string): string {
            const enable = enabled === "true"
            const interval = intervalMs ? parseInt(intervalMs) : wallpaperService.changeInterval

            wallpaperService.autoChange = enable
            wallpaperService.changeInterval = interval
            wallpaperService.configData.global.autoChange.enabled = enable
            wallpaperService.configData.global.autoChange.intervalMs = interval
            wallpaperService.saveConfig()

            return `Auto-change ${enable ? "enabled" : "disabled"} (interval: ${interval}ms)`
        }

        function setRandom(enabled: string): string {
            const value = enabled === "true"
            wallpaperService.randomOrder = value
            wallpaperService.configData.global.randomOrder = value
            const updatedRandom = Object.assign({}, wallpaperService.monitorRandomOrder)
            updatedRandom["__global"] = value
            wallpaperService.monitorRandomOrder = updatedRandom
            wallpaperService.saveConfig()
            return `Random order ${value ? "enabled" : "disabled"}`
        }

        function setFillMode(monitor: string, fillModeValue: string): string {
            const mode = parseInt(fillModeValue)
            wallpaperService.setFillMode(monitor, mode)
            return `FillMode set for ${monitor}: ${fillModeValue}`
        }

        function setFillModeAll(fillModeValue: string): string {
            const mode = parseInt(fillModeValue)
            wallpaperService.setAllMonitorsFillMode(mode)
            return `FillMode set for all monitors: ${fillModeValue}`
        }

        function status(): string {
            const monitorEntries = wallpaperService.knownMonitorKeys().map(monitor => {
                const dir = wallpaperService.monitorDirectories[monitor] || (wallpaperService.globalDirectory.length > 0 ? wallpaperService.globalDirectory : "")
                const wall = wallpaperService.getWallpaper(monitor)
                const fill = wallpaperService.getFillMode(monitor)
                return `${monitor} -> wallpaper: ${wall}, directory: ${dir}, fillMode: ${fill}`
            }).join("\n")

            return `Directory Mode: ${wallpaperService.directoryMode}
Global Directory: ${wallpaperService.globalDirectory}
Auto-change: ${wallpaperService.autoChange}
Interval: ${wallpaperService.changeInterval}ms
Random: ${wallpaperService.randomOrder}
Primary Monitor: ${wallpaperService.primaryMonitor}
Current Wallpaper: ${wallpaperService.currentWallpaper}
Monitors:
${monitorEntries}`
        }
    }
}
