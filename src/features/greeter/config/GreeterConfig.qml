pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // Greeter config + shell state symlink live in /etc/greetd/
    readonly property string greeterConfigPath: "/etc/greetd/greeter.json"
    readonly property string shellStatePath: "/etc/greetd/shell-state.json"  // symlink → user's state.json

    property bool ready: false
    property var data: ({})
    property var _shellState: ({})

    // Wallpaper: shell-state.json monitors → greeter config wallpaperPath → ""
    readonly property string wallpaperPath: {
        let monitors = _shellState.wallpaper?.monitors
        let primary = data.primaryMonitor ?? ""

        if (monitors) {
            if (primary && monitors[primary]?.currentItemId)
                return monitors[primary].currentItemId

            for (let name in monitors) {
                if (monitors[name]?.currentItemId)
                    return monitors[name].currentItemId
            }
        }

        return data.wallpaperPath ?? ""
    }

    readonly property bool darkMode: data.darkMode ?? true
    readonly property string themeVariant: data.themeVariant ?? "vibrant"
    readonly property string themeColor: data.themeColor ?? "#6200EE"
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
            root._checkReady()
        }

        onLoadFailed: error => {
            console.log("GreeterConfig: no config at", root.greeterConfigPath, "- using defaults")
            root.data = {}
            root._checkReady()
        }
    }

    // /etc/greetd/shell-state.json (symlink → ~/.config/quickshell/state.json)
    FileView {
        id: shellStateFile
        path: root.shellStatePath

        onLoaded: {
            try {
                root._shellState = JSON.parse(text()) || {}
            } catch (e) {
                console.warn("GreeterConfig: failed to parse", root.shellStatePath, e)
                root._shellState = {}
            }
            root._checkReady()
        }

        onLoadFailed: error => {
            console.log("GreeterConfig: shell state not found at", root.shellStatePath)
            root._shellState = {}
            root._checkReady()
        }
    }

    property int _loadedCount: 0
    function _checkReady() {
        _loadedCount++
        if (_loadedCount >= 2)
            root.ready = true
    }
}
