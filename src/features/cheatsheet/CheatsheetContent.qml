import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.src.ui.base
import qs.src.ui.containers
import qs.src.ui.feedback
import qs.src.core.config
import qs.src.core.services
import qs.src.features.cheatsheet.components as Components

pragma ComponentBehavior: Bound

Item {
    id: root

    // ═══════════════════════════════════════════════════════════════
    // DATA — Shell binds (static)
    // ═══════════════════════════════════════════════════════════════

    // Fallback descriptions for shell binds (used when hyprctl description is empty)
    readonly property var _shellDescriptions: ({
        "controlPanelToggle":  "Toggle control panel",
        "closeAllPanels":      "Close all open panels",
        "launcherToggle":      "Toggle application launcher",
        "screenshot":          "Take area screenshot",
        "screenshotSwappy":    "Take annotated screenshot (swappy)",
        "powerMenuToggle":     "Toggle power menu",
        "gamingModeToggle":    "Toggle gaming mode",
        "cheatsheetToggle":    "Toggle cheatsheet overlay",
        "brightnessUp":        "Increase screen brightness",
        "brightnessDown":      "Decrease screen brightness",
        "audioVolumeUp":       "Increase audio volume",
        "audioVolumeDown":     "Decrease audio volume",
        "audioVolumeMute":     "Toggle audio mute"
    })

    property var _shellBindsComputed: []

    // ═══════════════════════════════════════════════════════════════
    // DATA — IPC reference (static)
    // ═══════════════════════════════════════════════════════════════

    readonly property var _ipcData: [
        {
            name: "globalstates",
            functions: [
                { name: "toggleDashboard", params: "", description: "Toggle dashboard visibility" },
                { name: "toggleLauncher", params: "", description: "Toggle app launcher" },
                { name: "openLauncher", params: "", description: "Open app launcher" },
                { name: "closeLauncher", params: "", description: "Close app launcher" },
                { name: "closeAll", params: "", description: "Close all open panels" },
                { name: "toggleNotificationCenter", params: "", description: "Toggle notification center" },
                { name: "openNotificationCenter", params: "", description: "Open notification center" },
                { name: "closeNotificationCenter", params: "", description: "Close notification center" },
                { name: "screenshot", params: "", description: "Take area screenshot" },
                { name: "toggleGamingMode", params: "", description: "Toggle gaming mode" },
                { name: "enableGamingMode", params: "", description: "Enable gaming mode" },
                { name: "disableGamingMode", params: "", description: "Disable gaming mode" },
                { name: "togglePowerMenu", params: "", description: "Toggle power menu" },
                { name: "openPowerMenu", params: "", description: "Open power menu" },
                { name: "closePowerMenu", params: "", description: "Close power menu" },
                { name: "lockScreen", params: "", description: "Lock the session" },
                { name: "toggleCheatsheet", params: "", description: "Toggle cheatsheet overlay" },
                { name: "openCheatsheet", params: "", description: "Open cheatsheet overlay" },
                { name: "closeCheatsheet", params: "", description: "Close cheatsheet overlay" }
            ]
        },
        {
            name: "audio",
            functions: [
                { name: "volumeUp", params: "", description: "Increase master volume" },
                { name: "volumeDown", params: "", description: "Decrease master volume" },
                { name: "toggleMute", params: "", description: "Toggle master mute" },
                { name: "setVolume", params: "value: real", description: "Set master volume (0.0–1.0)" },
                { name: "getMasterVolume", params: "", description: "Get current master volume" },
                { name: "isMuted", params: "", description: "Check if master is muted" }
            ]
        },
        {
            name: "mpris",
            functions: [
                { name: "play", params: "", description: "Start playback" },
                { name: "pause", params: "", description: "Pause playback" },
                { name: "stop", params: "", description: "Stop playback" },
                { name: "togglePlaying", params: "", description: "Toggle play/pause" },
                { name: "next", params: "", description: "Skip to next track" },
                { name: "previous", params: "", description: "Go to previous track" },
                { name: "seek", params: "offset: real", description: "Seek by offset in seconds" },
                { name: "setPosition", params: "position: real", description: "Set playback position" },
                { name: "setVolume", params: "volume: real", description: "Set player volume" },
                { name: "volumeUp", params: "", description: "Increase player volume" },
                { name: "volumeDown", params: "", description: "Decrease player volume" },
                { name: "toggleShuffle", params: "", description: "Toggle shuffle mode" },
                { name: "toggleLoop", params: "", description: "Cycle loop mode" },
                { name: "raise", params: "", description: "Raise player window" },
                { name: "quit", params: "", description: "Quit the player" },
                { name: "getPosition", params: "", description: "Get current position" },
                { name: "getLength", params: "", description: "Get track length" },
                { name: "getVolume", params: "", description: "Get player volume" },
                { name: "isPlaying", params: "", description: "Check if playing" },
                { name: "getCurrentTrack", params: "", description: "Get current track info" }
            ]
        },
        {
            name: "wallpaper",
            functions: [
                { name: "set", params: "monitor, path", description: "Set wallpaper for monitor" },
                { name: "setAll", params: "path", description: "Set wallpaper for all monitors" },
                { name: "setDirectory", params: "monitor, dir", description: "Set wallpaper directory" },
                { name: "next", params: "monitor", description: "Next wallpaper" },
                { name: "previous", params: "monitor", description: "Previous wallpaper" },
                { name: "setAutoChange", params: "enabled, intervalMs", description: "Configure auto-change" },
                { name: "setRandom", params: "enabled", description: "Toggle random order" },
                { name: "setFillMode", params: "monitor, fillMode", description: "Set fill mode for monitor" },
                { name: "setFillModeAll", params: "fillMode", description: "Set fill mode for all monitors" },
                { name: "status", params: "", description: "Get wallpaper status" }
            ]
        }
    ]

    // ═══════════════════════════════════════════════════════════════
    // CATEGORY ORDER
    // ═══════════════════════════════════════════════════════════════

    readonly property var _categoryOrder: [
        "Applications", "Window Control", "Workspaces",
        "Focus and Movement", "Layout", "Modes",
        "Animations and Effects", "Misc Commands", "System",
        "Shell", "Other"
    ]

    // ═══════════════════════════════════════════════════════════════
    // STATE
    // ═══════════════════════════════════════════════════════════════

    property var _hyprlandBinds: []
    property var filteredBindCategories: []
    property var filteredIpcHandlers: []
    property int currentTab: 0

    // ═══════════════════════════════════════════════════════════════
    // PROCESS — hyprctl -j binds
    // ═══════════════════════════════════════════════════════════════

    Process {
        id: hyprBindsProc
        command: ["hyprctl", "-j", "binds"]

        stdout: StdioCollector {
            onStreamFinished: {
                root._processBinds(text)
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // JS FUNCTIONS
    // ═══════════════════════════════════════════════════════════════

    function decodeModmask(mask) {
        const mods = []
        if (mask & 64) mods.push("Super")
        if (mask & 4)  mods.push("Ctrl")
        if (mask & 8)  mods.push("Alt")
        if (mask & 1)  mods.push("Shift")
        return mods
    }

    function categorizeDispatcher(dispatcher) {
        const map = {
            "exec": "Applications", "execr": "Applications",
            "killactive": "Window Control", "closewindow": "Window Control",
            "fullscreen": "Window Control", "fullscreenstate": "Window Control",
            "fakefullscreen": "Window Control", "togglefloating": "Window Control",
            "pin": "Window Control", "centerwindow": "Window Control",
            "resizeactive": "Window Control", "moveactive": "Window Control",
            "toggleopaque": "Window Control", "setfloating": "Window Control",
            "settiled": "Window Control", "resizewindowpixel": "Window Control",
            "movewindowpixel": "Window Control", "minwindow": "Window Control",
            "workspace": "Workspaces", "movetoworkspace": "Workspaces",
            "movetoworkspacesilent": "Workspaces", "togglespecialworkspace": "Workspaces",
            "movefocus": "Focus and Movement", "swapwindow": "Focus and Movement",
            "cyclenext": "Focus and Movement", "focuswindow": "Focus and Movement",
            "alterzorder": "Focus and Movement", "focusurgentorlast": "Focus and Movement",
            "focuscurrentorlast": "Focus and Movement", "movewindow": "Focus and Movement",
            "bringactivetotop": "Focus and Movement", "swapnext": "Focus and Movement",
            "layoutmsg": "Layout", "togglesplit": "Layout",
            "pseudo": "Layout", "togglegroup": "Layout",
            "changegroupactive": "Layout", "movewindoworgroup": "Layout",
            "movegroupwindow": "Layout", "denywindowfromgroup": "Layout",
            "lockactivegroup": "Layout", "lockgroups": "Layout",
            "submap": "Modes",
            "exit": "System", "forcerendererreload": "System",
            "dpms": "Misc Commands", "pass": "Misc Commands",
            "sendshortcut": "Misc Commands", "global": "Misc Commands",
            "mouse": "Misc Commands", "movecursor": "Misc Commands",
            "renameworkspace": "Misc Commands", "setprop": "Misc Commands",
            "setcursor": "Misc Commands",
            "animationstyle": "Animations and Effects"
        }
        return map[dispatcher] || "Other"
    }

    function _processBinds(jsonText) {
        try {
            const parsed = JSON.parse(jsonText)
            const binds = []
            const shellBinds = []
            for (const b of parsed) {
                if (b.dispatcher === "global") {
                    // b.arg format: "quickshell:actionName"
                    const parts = (b.arg || "").split(":")
                    const action = parts.length > 1 ? parts[1] : b.arg
                    shellBinds.push({
                        type: "shell",
                        modifiers: decodeModmask(b.modmask),
                        key: b.key || ("keycode:" + b.keycode),
                        description: b.description || root._shellDescriptions[action] || action,
                        action: action,
                        category: "Shell"
                    })
                    continue
                }
                binds.push({
                    type: "hyprland",
                    modifiers: decodeModmask(b.modmask),
                    key: b.key || ("keycode:" + b.keycode),
                    description: b.description || "",
                    dispatcher: b.dispatcher,
                    arg: b.arg || "",
                    category: categorizeDispatcher(b.dispatcher),
                    submap: b.submap || ""
                })
            }
            _hyprlandBinds = binds
            _shellBindsComputed = shellBinds
        } catch (e) {
            console.warn("Cheatsheet: failed to parse hyprctl binds:", e)
            _hyprlandBinds = []
            _shellBindsComputed = []
        }
        _applyFilter()
    }

    function _applyFilter() {
        const query = searchField.text.toLowerCase().trim()
        const allBinds = _hyprlandBinds.concat(_shellBindsComputed)

        // Filter binds
        const filtered = query.length === 0 ? allBinds : allBinds.filter(b => {
            const desc = (b.description || "").toLowerCase()
            const key = (b.key || "").toLowerCase()
            const dispatcher = (b.dispatcher || "").toLowerCase()
            const arg = (b.arg || "").toLowerCase()
            const action = (b.action || "").toLowerCase()
            const mods = (b.modifiers || []).join(" ").toLowerCase()
            return desc.includes(query) || key.includes(query) ||
                   dispatcher.includes(query) || arg.includes(query) ||
                   action.includes(query) || mods.includes(query)
        })

        // Group by category in order
        const grouped = {}
        for (const b of filtered) {
            const cat = b.category || "Other"
            if (!grouped[cat]) grouped[cat] = []
            grouped[cat].push(b)
        }

        const result = []
        for (const cat of _categoryOrder) {
            if (grouped[cat] && grouped[cat].length > 0) {
                result.push({ name: cat, binds: grouped[cat] })
            }
        }
        filteredBindCategories = result

        // Filter IPC handlers
        if (query.length === 0) {
            filteredIpcHandlers = _ipcData
        } else {
            const ipcResult = []
            for (const handler of _ipcData) {
                const matchedFuncs = handler.functions.filter(f => {
                    return f.name.toLowerCase().includes(query) ||
                           handler.name.toLowerCase().includes(query) ||
                           f.description.toLowerCase().includes(query) ||
                           (f.params || "").toLowerCase().includes(query)
                })
                if (matchedFuncs.length > 0) {
                    ipcResult.push({
                        name: handler.name,
                        functions: matchedFuncs
                    })
                }
            }
            filteredIpcHandlers = ipcResult
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // VISUAL
    // ═══════════════════════════════════════════════════════════════

    readonly property var _tabs: [
        { icon: "keyboard", label: "Keybindings" },
        { icon: "terminal", label: "IPC Reference" }
    ]

    MaterialCard {
        id: card
        anchors.fill: parent
        outlined: false
        color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.95)
        radius: Tokens.shape.extraLarge

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Tokens.spacing.large
            spacing: Tokens.spacing.medium

            // ─── Header ─────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                MaterialIcon {
                    iconName: "help"
                    fontSize: Tokens.typography.titleLarge.size
                    iconColor: Theme.primary
                }

                MaterialText {
                    text: "Cheatsheet"
                    textStyle: "titleLarge"
                    colorRole: "onSurface"
                    Layout.fillWidth: true
                }

                IconButton {
                    iconName: "close"
                    iconSize: Tokens.iconSize.large
                    onClicked: GlobalStates.closePanel("cheatsheet")
                }
            }

            // ─── Search field ───────────────────────────────────
            Rectangle {
                id: searchContainer
                Layout.fillWidth: true
                Layout.preferredHeight: 56
                radius: Tokens.shape.full
                color: Theme.surfaceContainerHighest
                border.width: searchField.activeFocus ? 2 : 0
                border.color: searchField.activeFocus ? Theme.primary : "transparent"

                Behavior on border.width {
                    NumberAnimation {
                        duration: Tokens.motion.duration.short4
                        easing.type: Tokens.motion.easing.standard
                        easing.bezierCurve: Tokens.motion.easing.standardPoints
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Tokens.spacing.small
                    spacing: Tokens.spacing.small

                    MaterialIcon {
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24
                        iconName: "search"
                        iconColor: Theme.onSurfaceVariant
                    }

                    TextField {
                        id: searchField
                        Layout.fillWidth: true
                        placeholderText: "Search keybindings, commands..."
                        color: Theme.onSurface
                        font.pixelSize: Tokens.typography.bodyLarge.size
                        background: Item {}

                        onTextChanged: root._applyFilter()

                        Keys.onPressed: (event) => {
                            if (event.key === Qt.Key_Escape) {
                                if (searchField.text.length > 0) {
                                    searchField.text = ""
                                } else {
                                    GlobalStates.closePanel("cheatsheet")
                                }
                                event.accepted = true
                            } else if (event.key === Qt.Key_F && (event.modifiers & Qt.ControlModifier)) {
                                searchField.forceActiveFocus()
                                event.accepted = true
                            }
                        }

                        Keys.onTabPressed: (event) => {
                            if (event.modifiers & Qt.ShiftModifier) {
                                root.currentTab = root.currentTab === 0 ? 1 : 0
                            } else {
                                root.currentTab = root.currentTab === 0 ? 1 : 0
                            }
                            event.accepted = true
                        }

                        Keys.onBacktabPressed: (event) => {
                            root.currentTab = root.currentTab === 0 ? 1 : 0
                            event.accepted = true
                        }

                        Component.onCompleted: searchField.forceActiveFocus()
                    }

                    IconButton {
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24
                        iconName: "close"
                        visible: searchField.text.length > 0
                        iconSize: Tokens.iconSize.medium
                        onClicked: {
                            searchField.text = ""
                            searchField.forceActiveFocus()
                        }
                    }
                }
            }

            // ─── Tab bar ────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 0

                Repeater {
                    model: root._tabs

                    Item {
                        id: tabDelegate
                        required property var modelData
                        required property int index

                        Layout.fillWidth: true
                        Layout.preferredHeight: 48

                        readonly property bool isActive: root.currentTab === index

                        Rectangle {
                            anchors.fill: parent
                            radius: Tokens.shape.small
                            color: "transparent"

                            StateLayer {
                                target: parent
                                hovered: tabMouseArea.containsMouse
                                pressed: tabMouseArea.pressed
                                layerColor: Theme.primary
                            }

                            MouseArea {
                                id: tabMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: root.currentTab = tabDelegate.index
                            }

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: Tokens.spacing.small

                                MaterialIcon {
                                    iconName: tabDelegate.modelData.icon
                                    fontSize: Tokens.typography.bodyMedium.size
                                    iconColor: tabDelegate.isActive ? Theme.primary : Theme.onSurfaceVariant
                                }

                                MaterialText {
                                    text: tabDelegate.modelData.label
                                    textStyle: "labelLarge"
                                    color: tabDelegate.isActive ? Theme.primary : Theme.onSurfaceVariant
                                }
                            }

                            // Active indicator (bottom line)
                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: parent.width * 0.6
                                height: 2
                                radius: 1
                                color: Theme.primary
                                visible: tabDelegate.isActive

                                Behavior on width {
                                    NumberAnimation {
                                        duration: Tokens.motion.duration.short4
                                        easing.type: Tokens.motion.easing.standard
                                        easing.bezierCurve: Tokens.motion.easing.standardPoints
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Divider { Layout.fillWidth: true }

            // ─── Tab content — only the active tab exists (§10.14) ───
            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: root.currentTab

                Loader {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    active: root.currentTab === 0
                    sourceComponent: Component {
                        Components.KeybindingsTab {
                            categories: root.filteredBindCategories
                        }
                    }
                }
                Loader {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    active: root.currentTab === 1
                    sourceComponent: Component {
                        Components.IpcReferenceTab {
                            handlers: root.filteredIpcHandlers
                        }
                    }
                }
            }
        }
    }

    // Keyboard shortcut for Ctrl+F
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_F && (event.modifiers & Qt.ControlModifier)) {
            searchField.forceActiveFocus()
            event.accepted = true
        }
    }

    // Reset and fetch on visibility change
    onVisibleChanged: {
        if (visible) {
            searchField.text = ""
            currentTab = 0
            hyprBindsProc.running = true
            Qt.callLater(function() {
                searchField.forceActiveFocus()
            })
        }
    }

    Component.onCompleted: {
        hyprBindsProc.running = true
    }
}
