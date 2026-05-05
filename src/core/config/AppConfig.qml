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

    // === Typed accessors ===

    // Appearance
    readonly property string themeSource: data.appearance?.theme?.source ?? "wallpaper"
    readonly property bool darkMode: data.appearance?.theme?.darkMode ?? true
    readonly property string themeVariant: data.appearance?.theme?.variant ?? "tonalspot"
    readonly property real fontScale: data.appearance?.fontScale ?? 1.0

    // Bar
    readonly property bool barEnabled: data.bar?.enabled ?? true
    readonly property string barPosition: data.bar?.position ?? "top"
    readonly property int barHeight: data.bar?.height ?? 48
    readonly property int barMargin: data.bar?.margin ?? 16
    readonly property bool barTransparent: data.bar?.transparent ?? false
    readonly property var barWidgets: data.bar?.widgets || []

    // Dashboard
    readonly property bool dashboardEnabled: data.dashboard?.enabled ?? true
    readonly property int dashboardWidth: data.dashboard?.width ?? 900
    readonly property int dashboardHeight: data.dashboard?.height ?? 640

    // Notifications
    readonly property int notificationPanelWidth: data.notifications?.panel?.width ?? 400
    readonly property int notificationPopupWidth: data.notifications?.popup?.width ?? 360
    readonly property int notificationPopupTimeout: data.notifications?.popup?.timeout ?? 7000
    readonly property int notificationTimeoutLow: data.notifications?.popup?.timeoutLow ?? 3000
    readonly property int notificationTimeoutNormal: data.notifications?.popup?.timeoutNormal ?? 7000
    readonly property int notificationTimeoutCritical: data.notifications?.popup?.timeoutCritical ?? 15000
    readonly property int notificationPopupMaxVisible: data.notifications?.popup?.maxVisible ?? 5
    readonly property bool notificationGroupByApp: data.notifications?.panel?.groupByApp ?? true
    readonly property string notificationPopupPosition: data.notifications?.popup?.position ?? "top-right"
    readonly property int notificationHistoryTTLDays: data.notifications?.historyTTLDays ?? 30

    // Launcher
    readonly property int launcherMaxResults: data.launcher?.maxResults ?? 10
    readonly property int launcherWidth: data.launcher?.width ?? 600
    readonly property int launcherListMaxHeight: data.launcher?.listMaxHeight ?? 400
    readonly property int launcherTopMargin: data.launcher?.topMargin ?? 56

    // Services
    readonly property bool weatherEnabled: data.services?.weather?.enabled ?? true
    readonly property string weatherLocation: data.services?.weather?.location ?? "London"
    readonly property real weatherLatitude: data.services?.weather?.latitude ?? 53.2
    readonly property real weatherLongitude: data.services?.weather?.longitude ?? 45.0
    readonly property int weatherRefreshMinutes: data.services?.weather?.refreshMinutes ?? 15
    readonly property string weatherUnits: data.services?.weather?.units ?? "metric"
    readonly property bool calendarRemindersEnabled: data.services?.calendar?.reminders?.enabled ?? true
    readonly property int calendarReminderMinutes: data.services?.calendar?.reminders?.minutesBefore ?? 15
    readonly property int calendarReminderLookaheadDays: data.services?.calendar?.reminders?.lookaheadDays ?? 2
    readonly property int calendarDayViewHourHeight: data.services?.calendar?.dayView?.hourHeight ?? 60
    readonly property int calendarFirstDayOfWeek: data.services?.calendar?.firstDayOfWeek ?? 1
    readonly property bool vpnEnabled: data.services?.vpn?.enabled ?? false
    readonly property string vpnName: data.services?.vpn?.name ?? ""

    // Feed
    readonly property bool feedEnabled: data.feed?.enabled ?? false
    readonly property int feedPanelWidth: data.feed?.panelWidth ?? 520
    readonly property int feedRefreshMinutes: data.feed?.refreshMinutes ?? 30
    readonly property int feedMaxArticles: data.feed?.maxArticles ?? 100
    readonly property var feedSources: data.feed?.feeds ?? []

    // OSD
    readonly property bool osdEnabled: data.osd?.enabled ?? true
    readonly property int osdTimeout: data.osd?.timeout ?? 2000

    // Lockscreen
    readonly property bool lockscreenEnabled: data.lockscreen?.enabled ?? false
    readonly property bool lockscreenBlurWallpaper: data.lockscreen?.blurWallpaper ?? true
    readonly property bool lockscreenShowClock: data.lockscreen?.showClock ?? true

    // Power Menu
    readonly property bool powerMenuEnabled: data.powerMenu?.enabled ?? true
    readonly property bool powerMenuConfirmActions: data.powerMenu?.confirmActions ?? true
    readonly property var powerMenuActions: data.powerMenu?.actions ?? ["lock", "suspend", "reboot", "shutdown"]

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
    readonly property bool dockEnabled: data.dock?.enabled ?? false
    readonly property bool dockAutoHide: data.dock?.autoHide ?? true
    readonly property bool dockExclusive: data.dock?.exclusive ?? false
    readonly property int dockIconSize: data.dock?.iconSize ?? 48
    readonly property var dockPinnedApps: data.dock?.pinnedApps ?? []

    // Night Light
    readonly property int nightLightTemperature: data.services?.nightLight?.temperature ?? 4500

    // Hyprland
    readonly property int hyprlandWorkspaceCount: data.hyprland?.workspaceCount ?? 10

    // Wallpaper
    readonly property string wallpaperPrimaryMonitor: data.wallpaper?.primaryMonitor ?? ""
    readonly property string wallpaperDefaultPath: data.wallpaper?.defaultWallpaper ?? ""
    readonly property string wallpaperPostScript: data.wallpaper?.postSetScript ?? ""
    readonly property bool wallpaperAutoChange: data.wallpaper?.global?.autoChange?.enabled ?? false
    readonly property int wallpaperAutoChangeInterval: data.wallpaper?.global?.autoChange?.intervalMs ?? 300000
    readonly property bool wallpaperRandomOrder: data.wallpaper?.global?.randomOrder ?? true
    readonly property string wallpaperGlobalDirectory: data.wallpaper?.global?.directory ?? ""
    readonly property var wallpaperMonitors: data.wallpaper?.monitors ?? ({})

    // Wallpaper state (from state.json)
    readonly property var wallpaperState: stateData.wallpaper ?? ({})

    property bool _suppressConfigReload: false

    // FileView for config loading
    FileView {
        id: configFile
        path: root.configPath
        watchChanges: true

        onLoaded: {
            if (root._suppressConfigReload) {
                root._suppressConfigReload = false
                return
            }
            console.log("Config loaded from:", root.configPath)
            root.data = root.parseConfigText(text())
            root.ready = true
        }

        onLoadFailed: error => {
            console.warn("Failed to load config:", error)
            console.log("Loading default config from:", root.defaultConfigPath)
            root.loadDefaultConfig()
        }

        onFileChanged: {
            console.log("Config file changed, reloading...")
            reload()
        }
    }

    function parseConfigText(rawText) {
        try {
            const parsed = JSON.parse(rawText)
            return parsed || {}
        } catch (e) {
            console.warn("Config parse: failed to parse JSON", e)
            return {}
        }
    }

    function loadDefaultConfig() {
        defaultConfigLoader.path = root.defaultConfigPath
    }

    FileView {
        id: defaultConfigLoader

        onLoaded: {
            console.log("Default config loaded from:", root.defaultConfigPath)
            root.data = root.parseConfigText(text())
            root.ready = true
        }

        onLoadFailed: error => {
            console.error("Failed to load default config:", error)
            root.data = {}
            root.ready = true
        }
    }

    // === State persistence (state.json) ===
    readonly property string statePath: configDir + "/quickshell/state.json"
    property var stateData: ({})

    property bool _stateLoaded: false
    readonly property bool stateReady: _stateLoaded

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
        }

        onLoadFailed: error => {
            console.log("AppConfig: state.json not found, will be created on first write")
            root.stateData = {}
            root._stateLoaded = true
        }
    }

    Timer {
        id: configSaveTimer
        interval: 500
        repeat: false
        onTriggered: {
            root._suppressConfigReload = true
            configFile.setText(JSON.stringify(root.data, null, 2))
        }
    }

    function updateConfig(section, newData) {
        let current = Object.assign({}, root.data || {})
        current[section] = newData
        root.data = current
        configSaveTimer.restart()
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
        let current = root.stateData || {}
        current[section] = Object.assign(current[section] || {}, data)
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
