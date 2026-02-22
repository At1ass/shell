pragma Singleton

import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // Config file paths
    readonly property string configDir: Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")
    readonly property string configPath: configDir + "/quickshell/shell/config.json"
    readonly property string defaultConfigPath: Qt.resolvedUrl("../../../config/default.json").toString().replace("file://", "")

    // Ready flag
    property bool ready: false

    // Raw JSON data
    property var data: ({})

    // Typed accessors
    readonly property int barHeight: data.bar?.height ?? 48
    readonly property var barWidgets: data.bar?.widgets || []
    readonly property string weatherLocation: data.services?.weather?.location ?? "London"
    readonly property int weatherRefreshMinutes: data.services?.weather?.refreshMinutes ?? 15

    // FileView for config loading
    FileView {
        id: configFile
        path: root.configPath
        watchChanges: true

        onLoaded: {
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
