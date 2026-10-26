pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // Everything the greeter reads lives in /etc/greetd/, root-owned, and
    // nothing comes from the user's home. It used to follow the shell's current
    // wallpaper through /etc/greetd/shell-state.json (a symlink into
    // ~/.config/quickshell/state.json) plus ACLs on ~/wallpapers. The traverse
    // right on ~ that this required also let the greeter user read every
    // world-readable file in the home directory, for the sake of one path.
    // The background is now an image copied into /etc/greetd by hand.
    readonly property string greeterConfigPath: "/etc/greetd/greeter.json"

    property bool ready: false
    property string configError: ""
    property string _raw: "{}"
    property bool _fileReady: false
    property var _schema: null
    function applyConfig() {
        if (!_fileReady || !_schema) return
        const result = ConfigValidator.parse(_raw, _schema)
        configError = result.errors.map(error => error.path + ": " + error.message).join("; ")
        data = result.errors.length === 0 ? result.value : ({})
        ready = true
    }
    property var data: ({})

    // Background image and palette seed; empty -> solid surfaceDim.
    readonly property string wallpaperPath: data.wallpaperPath ?? ""

    readonly property bool darkMode: data.darkMode ?? true
    readonly property string themeVariant: data.themeVariant ?? "vibrant"
    readonly property string themeColor: data.themeColor ?? "#6200EE"
    // 0.0 = standard M3. 1.0 is MCU's accessibility high-contrast level.
    readonly property real themeContrast: data.themeContrast ?? 0.0
    readonly property string designSystem: data.designSystem === "md3" ? "md3" : "minimal"
    readonly property real fontScale: typeof data.fontScale === "number" && data.fontScale >= 0.75 && data.fontScale <= 2 ? data.fontScale : 1.3
    readonly property bool reduceMotion: data.reduceMotion === true
    readonly property bool showDate: data.showDate ?? true
    readonly property bool showBattery: data.showBattery ?? true
    readonly property bool showPower: data.showPower ?? true
    readonly property bool blurWallpaper: data.blurWallpaper ?? true
    readonly property bool showClock: data.showClock ?? true
    readonly property string defaultUser: data.defaultUser ?? ""
    readonly property string defaultSession: data.defaultSession ?? ""

    FileView {
        path: Qt.resolvedUrl("greeter.schema.json")
        onLoaded: { root._schema = JSON.parse(text()); root.applyConfig() }
        onLoadFailed: {
            root.configError = "Greeter schema unavailable; using defaults"
            root.data = {}
            root.ready = true
        }
    }
    FileView {
        path: root.greeterConfigPath
        onLoaded: { root._raw = text(); root._fileReady = true; root.applyConfig() }
        onLoadFailed: { root._raw = "{}"; root._fileReady = true; root.applyConfig() }
    }
}
