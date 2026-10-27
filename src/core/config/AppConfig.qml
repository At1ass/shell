pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // Config file paths
    readonly property string configDir: Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")
    readonly property string configPath: configDir + "/quickshell/config.json"
    readonly property string defaultConfigPath: Qt.resolvedUrl("../../../config/default.json").toString().replace("file://", "")

    // Ready flag
    property bool ready: false

    // Raw JSON data
    property var data: ({})

    // === Module toggles ===
    // Central on/off map for every top-level UI element. A user disables anything
    // via the `modules` block in config.json; absent keys fall back to these defaults.
    readonly property var moduleDefaults: ({
        overview: true, bar: true, dock: false, wallpaper: true, dashboard: true, connections: true, audio: true,
        launcher: true, notifications: true, osd: true, lockscreen: false,
        powerMenu: true, cheatsheet: true, screenshot: true, toasts: true, popouts: true,
        polkit: false, recorder: true
    })

    function moduleEnabled(name) {
        const v = data.modules ? data.modules[name] : undefined
        return (v === undefined || v === null) ? (moduleDefaults[name] ?? true) : v
    }

    // === Config validation ===
    //
    // Config-first means config.json IS the interface, and a typo in it used to
    // do nothing observable: the key was ignored, the accessor fell back to its
    // default, and the user was left believing a setting that never applied.
    // The schema described every key exactly and was simply never executed.
    //
    // Errors are PUBLISHED, not shown: this layer must not reach into services
    // (AGENTS §3), so shell.qml turns them into a toast.
    property var configErrors: []
    property var _schema: null
    property string _schemaError: ""
    property var _defaults: null
    property string _configText: ""
    property string _configReadError: ""
    property bool _configReceived: false
    property bool _hasUserConfig: false
    property bool _configReadPending: true

    FileView {
        id: schemaFile
        path: Qt.resolvedUrl("../../../config/config.schema.json").toString().replace("file://", "")
        onLoaded: {
            try {
                root._schema = JSON.parse(text())
            } catch (e) {
                root._schemaError = "Cannot parse config.schema.json: " + e.message
            }
            root._applyCandidate()
        }
        onLoadFailed: {
            root._schemaError = "Cannot read config.schema.json"
            root._applyCandidate()
        }
    }

    // Publish a complete validated snapshot only. A rejected edit leaves every
    // consumer on the last good snapshot; diagnostics describe the rejected file.
    function _applyCandidate() {
        if (!root._configReceived || root._defaults === null)
            return
        if (!root._schema && root._schemaError === "")
            return
        let errors = []
        let candidate = root._defaults
        if (root._schemaError !== "") {
            errors = [{ path: "(schema)", message: root._schemaError }]
        } else if (root._configReadError !== "") {
            errors = [{ path: "(file)", message: root._configReadError }]
        } else if (root._hasUserConfig) {
            const result = ConfigValidator.parse(root._configText, root._schema)
            candidate = result.value
            errors = result.errors
        }
        root.configErrors = errors
        for (const e of errors)
            console.warn(`config.json: ${e.path}: ${e.message}`)
        if (errors.length === 0)
            root.data = candidate
        else if (!root.ready)
            root.data = root._defaults
        root.ready = true
    }

    // Same validator the shell runs on load, reachable from outside so a
    // config can be checked WITHOUT reloading the shell and reading its log.
    // Config-first means the file is the interface; this is how you interrogate
    // it. Lives here rather than in a CLI reimplementation so there is exactly
    // one notion of "valid".
    IpcHandler {
        target: "config"

        function validate(): string {
            if (!root._schema)
                return "schema unavailable (config/config.schema.json not readable)"
            if (root._configReadPending)
                return "config.json read in progress"
            if (!root.ready)
                return "configuration is not ready"
            const errors = root.configErrors
            if (errors.length === 0)
                return "OK: " + root.configPath + " matches the schema"
            const lines = errors.map(e => `  ${e.path}: ${e.message}`)
            return `${errors.length} problem(s) in ${root.configPath}\n` + lines.join("\n")
        }

        function path(): string {
            return root.configPath
        }

        function schemaPath(): string {
            return schemaFile.path
        }

        function statePath(): string {
            return root.statePath
        }
    }

    // === Performance profile ===

    // Panels retained after their first open. Rebuilding a panel blocks the UI
    // thread for the whole of its construction, and every panel here is a
    // LazyLoader keyed on its own open flag, so that bill used to come due on
    // EVERY open rather than once. See GlobalStates.panelRetained.
    readonly property var keepPanelsLoaded:
        data.performance?.keepPanelsLoaded ?? ["launcher", "dashboard", "notificationCenter", "cheatsheet"]

    function panelKeptLoaded(name) {
        return root.keepPanelsLoaded.indexOf(name) !== -1
    }

    // === Typed accessors ===

    // Appearance
    readonly property bool darkMode: data.appearance?.theme?.darkMode ?? true
    readonly property string themeVariant: data.appearance?.theme?.variant ?? "tonalspot"
    // MCU contrast level. 0.0 = standard M3. This used to be hardcoded at 0.5
    // in Theme.qml, which is the accessibility HIGH-CONTRAST variant: in a dark
    // scheme it inverts container polarity, so every *Container role came out
    // light with black text on it. See appearance.theme.contrast in the schema.
    readonly property real themeContrast: data.appearance?.theme?.contrast ?? 0.0
    // Which design pack Tokens resolves: "md3" or "minimal". Anything else falls
    // back to md3 rather than leaving the shell with unset tokens.
    readonly property string designSystem: data.appearance?.designSystem === "minimal" ? "minimal" : "md3"
    readonly property real fontScale: data.appearance?.fontScale ?? 1.3
    // Empty means "whatever the design pack asks for" -- see Tokens.typography.
    readonly property string fontFamily: data.appearance?.fontFamily ?? ""
    readonly property string monoFamily: data.appearance?.monoFamily ?? ""
    // Opacity of the shell's own panel surfaces. Opaque by default: a panel you
    // can read the desktop through is not a composition, and the compositor
    // cannot fix that from its side -- Hyprland's layer rules carry `blur` and
    // `ignore_alpha` but no opacity, so how solid a layer is stays the client's
    // call. Lower this to hand the compositor something to blur.
    readonly property real panelOpacity: Math.max(0.1, Math.min(1.0, data.appearance?.panelOpacity ?? 1.0))
    readonly property bool reduceMotion: data.appearance?.reduceMotion ?? false
    readonly property real motionScale: data.appearance?.motionScale ?? 1.0

    // Bar
    readonly property string barPosition: data.bar?.position ?? "top"
    readonly property int barHeight: data.bar?.height ?? 48
    readonly property int barMargin: notificationPopupMargin
    readonly property bool barTransparent: data.bar?.transparent ?? false
    readonly property bool barAutoHide: data.bar?.autoHide ?? false
    function barWidgetPriority(widget): int {
        const automatic = {clock:100,workspaces:90,battery:85,volume:80,network:75,notifications:70,layout:60,tray:50,media:40,weather:30,activewindow:20}
        return widget?.priority ?? automatic[widget?.type] ?? 50
    }
    readonly property var barWidgets: data.bar?.widgets || []

    readonly property bool overviewShowPreviews: data.overview?.showPreviews ?? true
    readonly property int overviewFirstWorkspace: data.overview?.firstWorkspace ?? 1
    readonly property int overviewWorkspaceCount: data.overview?.workspaceCount ?? 9
    readonly property int overviewColumns: data.overview?.columns ?? 3
    readonly property bool overviewIncludeSpecial: data.overview?.includeSpecial ?? true

    // Dashboard
    readonly property int audioWidth: data.audio?.width ?? 420
    readonly property int audioMaxHeight: data.audio?.maxHeight ?? 640

    readonly property bool networkAgentEnabled: data.connections?.networkAgent ?? true
    readonly property int networkAuthenticationTimeout: data.connections?.authenticationTimeout ?? 120
    readonly property bool bluetoothAgentEnabled: data.connections?.bluetoothAgent ?? true
    readonly property int bluetoothPairingTimeout: data.connections?.pairingTimeout ?? 120
    readonly property int connectionsWidth: data.connections?.width ?? 420
    readonly property int connectionsMaxHeight: data.connections?.maxHeight ?? 640

    readonly property int dashboardWidth: data.dashboard?.width ?? 900
    readonly property int dashboardHeight: data.dashboard?.height ?? 640

    // Storage display policy; the native worker performs discovery and grouping.
    readonly property real storageWarningFreePercent: data.storage?.warningFreePercent ?? 10
    readonly property real storageCriticalFreePercent: data.storage?.criticalFreePercent ?? 5
    readonly property list<string> storageExcludedMounts: data.storage?.excludedMounts ?? ["/boot", "/boot/efi", "/efi"]
    readonly property list<string> storageOrder: data.storage?.order ?? ["/", "/home"]
    readonly property var storageLabels: data.storage?.labels ?? ({})

    // Notifications
    readonly property int notificationPanelWidth: data.notifications?.panel?.width ?? 400
    readonly property int notificationPopupWidth: data.notifications?.popup?.width ?? 360
    readonly property int notificationPopupMargin: data.notifications?.popup?.margin ?? data.bar?.margin ?? 16
    // Base timeout. `timeoutNormal` falls back to it rather than to a second
    // hardcoded 7000 — otherwise `popup.timeout` had no reachable effect at all
    // (every urgency had its own default), which is how it sat dead in the
    // schema while its description promised it was the fallback.
    readonly property int notificationPopupTimeout: data.notifications?.popup?.timeout ?? 7000
    readonly property int notificationTimeoutLow: data.notifications?.popup?.timeoutLow ?? 3000
    readonly property int notificationTimeoutNormal: data.notifications?.popup?.timeoutNormal ?? notificationPopupTimeout
    readonly property int notificationTimeoutCritical: data.notifications?.popup?.timeoutCritical ?? 15000
    readonly property int notificationPopupMaxVisible: data.notifications?.popup?.maxVisible ?? 5
    readonly property int notificationClearUndoTimeout: data.notifications?.panel?.clearUndoTimeout ?? 8000
    readonly property bool notificationGroupByApp: data.notifications?.panel?.groupByApp ?? true
    readonly property string notificationPopupPosition: data.notifications?.popup?.position ?? "top-right"
    // "focused" or an exact output name. See NotificationPopupManager._targetScreen.
    readonly property string notificationPopupMonitor: data.notifications?.popup?.monitor ?? "focused"
    readonly property int notificationHistoryTTLDays: data.notifications?.historyTTLDays ?? 30
    readonly property int notificationMaxHistory: data.notifications?.maxHistory ?? 200
    readonly property bool notificationSuppressOnFullscreen: data.notifications?.dnd?.suppressOnFullscreen ?? true

    // Burst protection (see NotificationRateLimiter for what each stage does).
    readonly property int notificationIngressPerSecond: data.notifications?.rateLimit?.ingressPerSecond ?? 20
    readonly property int notificationMaxQueue: data.notifications?.rateLimit?.maxQueue ?? 32
    readonly property int notificationPopupIntervalMs: data.notifications?.rateLimit?.popupIntervalMs ?? 350
    readonly property int notificationMaxPopupQueue: data.notifications?.rateLimit?.maxPopupQueue ?? 8

    // Per-app filters, lowercased once here so the hot path is a plain lookup.
    readonly property var notificationNoPopupApps: (data.notifications?.filters?.noPopup ?? []).map(s => String(s).toLowerCase())
    readonly property var notificationNoHistoryApps: (data.notifications?.filters?.noHistory ?? []).map(s => String(s).toLowerCase())

    readonly property var temporaryModeDurations: data.temporaryModes?.durationsMinutes ?? [15, 30, 60, 120]

    // Launcher
    readonly property int launcherMaxResults: data.launcher?.maxResults ?? 10
    readonly property int launcherWidth: data.launcher?.width ?? 600
    readonly property int launcherListMaxHeight: data.launcher?.listMaxHeight ?? 400
    readonly property int launcherTopMargin: data.launcher?.topMargin ?? 56
    readonly property var launcherHiddenApps: data.launcher?.hiddenApps ?? []

    // Services
    readonly property bool weatherEnabled: data.services?.weather?.enabled ?? true
    readonly property string weatherLocation: data.services?.weather?.location ?? "London"
    readonly property real weatherLatitude: data.services?.weather?.latitude ?? 51.5
    readonly property real weatherLongitude: data.services?.weather?.longitude ?? -0.12
    readonly property int weatherRefreshMinutes: data.services?.weather?.refreshMinutes ?? 15
    readonly property string weatherUnits: data.services?.weather?.units ?? "metric"
    readonly property bool calendarRemindersEnabled: data.services?.calendar?.reminders?.enabled ?? true
    readonly property int calendarReminderMinutes: data.services?.calendar?.reminders?.minutesBefore ?? 15
    readonly property int calendarReminderLookaheadDays: data.services?.calendar?.reminders?.lookaheadDays ?? 2
    // All-day events have no start time, so "N minutes before" cannot apply;
    // they remind once at this hour on the day itself.
    readonly property string calendarReminderAllDayTime: data.services?.calendar?.reminders?.allDayTime ?? "09:00"
    readonly property int calendarDayViewHourHeight: data.services?.calendar?.dayView?.hourHeight ?? 60
    readonly property int calendarFirstDayOfWeek: data.services?.calendar?.firstDayOfWeek ?? 1
    readonly property bool vpnEnabled: data.services?.vpn?.enabled ?? false

    // OSD
    readonly property string osdMonitorPolicy: data.osd?.monitorPolicy ?? "focused"
    readonly property int osdTimeout: data.osd?.timeout ?? 2000

    // Screen recording. Empty socket means the gsr default this shell assumes,
    // $XDG_RUNTIME_DIR/gsr-record.sock -- resolved in RecorderService, since the
    // config layer has no business reading the environment.
    readonly property string recorderSocket: data.recorder?.socket ?? ""
    readonly property string recorderDirectory: data.recorder?.output?.directory ?? ""
    readonly property string recorderContainer: data.recorder?.output?.container ?? "mkv"
    readonly property string recorderTarget: data.recorder?.capture?.target ?? "portal"
    readonly property bool recorderRestorePortal: data.recorder?.capture?.restorePortalSession ?? true
    readonly property bool recorderCursor: data.recorder?.capture?.cursor ?? true
    readonly property int recorderFps: data.recorder?.video?.fps ?? 60
    readonly property string recorderCodec: data.recorder?.video?.codec ?? "av1"
    readonly property string recorderQuality: data.recorder?.video?.quality ?? "very_high"
    readonly property string recorderFramerateMode: data.recorder?.video?.framerateMode ?? "vfr"
    readonly property var recorderAudioSources: data.recorder?.audio?.sources ?? ["default_output"]
    readonly property string recorderIndicatorPosition: data.recorder?.indicator?.position ?? "topRight"
    readonly property int recorderIndicatorMargin: data.recorder?.indicator?.margin ?? 24
    readonly property bool recorderIndicatorControls: data.recorder?.indicator?.showControls ?? true
    readonly property bool recorderIndicatorOnCaptured: data.recorder?.indicator?.showOnCapturedMonitor ?? true

    // Lockscreen
    readonly property bool lockscreenBlurWallpaper: data.lockscreen?.blurWallpaper ?? true
    readonly property bool lockscreenShowClock: data.lockscreen?.showClock ?? true
    readonly property bool lockscreenShowDate: data.lockscreen?.showDate ?? true
    readonly property bool lockscreenShowUsername: data.lockscreen?.showUsername ?? true
    readonly property bool lockscreenShowWeather: data.lockscreen?.showWeather ?? false
    readonly property bool lockscreenShowBattery: data.lockscreen?.showBattery ?? true
    readonly property bool lockscreenShowNetwork: data.lockscreen?.showNetwork ?? false
    readonly property bool lockscreenShowPower: data.lockscreen?.showPower ?? true
    readonly property bool lockscreenShowMedia: data.lockscreen?.showMedia ?? true
    readonly property bool lockscreenMediaShowPaused: data.lockscreen?.mediaShowPaused ?? true
    readonly property bool lockscreenMediaShowArt: data.lockscreen?.mediaShowArt ?? false

    // Power Menu
    readonly property bool powerMenuConfirmActions: data.powerMenu?.confirmActions ?? true
    readonly property var powerMenuActions: data.powerMenu?.actions ?? ["lock", "suspend", "reboot", "shutdown", "logout"]

    // Gaming Mode
    readonly property bool gmDisableAnimations: data.gamingMode?.disableAnimations ?? true
    readonly property bool gmDisableWeather: data.gamingMode?.disableWeather ?? true
    readonly property bool gmDisableWallpaperChange: data.gamingMode?.disableWallpaperChange ?? true
    readonly property bool gmHyprDisableAnimations: data.gamingMode?.hyprland?.disableAnimations ?? true
    readonly property bool gmHyprDisableBlur: data.gamingMode?.hyprland?.disableBlur ?? true
    readonly property bool gmHyprDisableShadows: data.gamingMode?.hyprland?.disableShadows ?? true
    readonly property int  gmHyprGaps: data.gamingMode?.hyprland?.gaps ?? 0
    readonly property int  gmHyprRounding: data.gamingMode?.hyprland?.rounding ?? 0

    // Dock
    readonly property string dockPosition: data.dock?.position ?? "bottom"
    readonly property bool dockAutoHide: data.dock?.autoHide ?? true
    readonly property bool dockExclusive: data.dock?.exclusive ?? false
    readonly property int dockIconSize: data.dock?.iconSize ?? 48
    readonly property var dockPinnedApps: data.dock?.pinnedApps ?? []

    // Night Light
    readonly property int nightLightTemperature: data.services?.nightLight?.temperature ?? 4500

    // Wallpaper — top-level keys read by WallpaperManager.
    // Per-monitor settings (sourceId, fillMode, autoChange, randomOrder) are
    // read directly via data.wallpaper.monitors[name] inside WallpaperManager.
    readonly property string wallpaperPrimaryMonitor: data.wallpaper?.primaryMonitor ?? ""
    readonly property string wallpaperDefaultPath: data.wallpaper?.defaultWallpaper ?? ""
    readonly property string wallpaperPostScript: data.wallpaper?.postSetScript ?? ""

    // Wallpaper state (from state.json)
    readonly property var wallpaperState: stateData.wallpaper ?? ({})

    FileView {
        id: configFile
        path: root.configPath
        watchChanges: true
        onLoaded: {
            root._configText = text()
            root._configReadError = ""
            root._hasUserConfig = true
            root._configReceived = true
            root._configReadPending = false
            root._applyCandidate()
        }
        onLoadFailed: error => {
            root._hasUserConfig = false
            root._configReadError = error === FileViewError.FileNotFound && !root.ready
                ? "" : "Cannot read config.json (error " + error + ")"
            root._configReceived = true
            root._configReadPending = false
            root._applyCandidate()
        }
        onFileChanged: {
            root._configReadPending = true
            reload()
        }
    }

    FileView {
        id: defaultConfigLoader
        path: root.defaultConfigPath
        onLoaded: {
            try {
                const parsed = JSON.parse(text())
                if (!parsed || Array.isArray(parsed) || typeof parsed !== "object")
                    throw new Error("expected an object")
                root._defaults = parsed
            } catch (e) {
                root.configErrors = [{ path: "(defaults)", message: "Invalid default.json: " + e.message }]
                return
            }
            root._applyCandidate()
        }
        onLoadFailed: {
            root.configErrors = [{ path: "(defaults)", message: "Cannot read default.json" }]
        }
    }

    // === State persistence (state.json) ===
    readonly property string statePath: configDir + "/quickshell/state.json"
    property var stateData: ({})

    property bool _stateLoaded: false
    readonly property bool stateReady: _stateLoaded

    // Writes that arrive before state.json finished loading. Applying them
    // immediately would merge into an EMPTY stateData; if the save timer then
    // fired first, the file on disk would be overwritten with that single
    // section (dock pins / gaming mode / DND destroyed).
    property var _pendingStateWrites: []

    function _flushPendingStateWrites() {
        const pending = _pendingStateWrites
        _pendingStateWrites = []
        for (const w of pending) updateState(w.section, w.data)
    }

    FileView {
        id: stateFile
        watchChanges: false

        onLoaded: {
            try {
                root.stateData = JSON.parse(text()) || {}
            } catch (e) {
                console.warn("AppConfig: state.json parse failed, starting with empty state:", e)
                root.stateData = {}
            }
            root._stateLoaded = true
            root._flushPendingStateWrites()
        }

        onLoadFailed: error => {
            // Normal on first run: state.json is created on first write.
            root.stateData = {}
            root._stateLoaded = true
            root._flushPendingStateWrites()
        }
    }

    Timer {
        id: stateSaveTimer
        interval: 500
        repeat: false
        onTriggered: {
            stateFile.setText(JSON.stringify(root.stateData, null, 2))
        }
    }

    function updateState(section, data) {
        if (!_stateLoaded) {
            _pendingStateWrites.push({ section: section, data: data })
            return
        }
        // Assign a NEW top-level object so the `var` property emits stateDataChanged
        // (reassigning the same reference does not — bindings would not re-evaluate).
        let current = Object.assign({}, root.stateData || {})
        current[section] = Object.assign({}, current[section] || {}, data)
        root.stateData = current
        stateSaveTimer.restart()
    }

    Component.onCompleted: {
        stateFile.path = root.statePath
    }

    function shouldShowOnMonitor(widgetConfig, monitorName) {
        if (!widgetConfig || !monitorName) {
            return true;
        }

        if (widgetConfig.enabled === false) {
            return false;
        }

        const monitors = widgetConfig.monitors;
        if (!monitors || monitors === "all") {
            return true;
        }

        if (Array.isArray(monitors)) {
            return monitors.indexOf(monitorName) !== -1;
        }

        if (typeof monitors === "string") {
            return monitors === monitorName;
        }

        return true;
    }
}
