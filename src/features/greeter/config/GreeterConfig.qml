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
    property var data: ({})

    // Background image and palette seed; empty -> solid surfaceDim.
    readonly property string wallpaperPath: data.wallpaperPath ?? ""

    readonly property bool darkMode: data.darkMode ?? true
    readonly property string themeVariant: data.themeVariant ?? "vibrant"
    readonly property string themeColor: data.themeColor ?? "#6200EE"
    // 0.0 = standard M3. 1.0 is MCU's accessibility high-contrast level.
    readonly property real themeContrast: data.themeContrast ?? 0.0
    readonly property bool showClock: data.showClock ?? true
    readonly property string defaultUser: data.defaultUser ?? ""
    readonly property string defaultSession: data.defaultSession ?? ""

    // /etc/greetd/greeter.json
    FileView {
        id: greeterConfigFile
        path: root.greeterConfigPath

        onLoaded: {
            try {
                root.data = JSON.parse(text()) || {}
            } catch (e) {
                console.warn("GreeterConfig: failed to parse", root.greeterConfigPath, e)
                root.data = {}
            }
            root.ready = true
        }

        onLoadFailed: error => {
            console.info("GreeterConfig: no config at", root.greeterConfigPath, "- using defaults")
            root.data = {}
            root.ready = true
        }
    }
}
