import QtQuick
import Quickshell.Io
import qs.src.core.services
import qs.src.features.cheatsheet.components as Components
import "components/BindFormatting.js" as BindFormatting

pragma ComponentBehavior: Bound

Item {
    id: root

    // ═══════════════════════════════════════════════════════════════
    // DATA — Shell binds (static)
    // ═══════════════════════════════════════════════════════════════

    // Fallback descriptions for shell binds (used when hyprctl description is empty)
    readonly property var _shellDescriptions: ({
        "connectionsToggle": "Toggle connections panel",
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
        "nightLightToggle":    "Toggle night light",
        "audioVolumeMute":     "Toggle audio mute"
    })

    property var _shellBindsComputed: []

    // IPC signatures are discovered on open; descriptions only enrich them.
    readonly property var _ipcData: Components.IpcReferenceData.handlers

    // ═══════════════════════════════════════════════════════════════
    // CATEGORY ORDER
    // ═══════════════════════════════════════════════════════════════

    readonly property var _categoryOrder: [
        "Applications", "Window Control", "Workspaces",
        "Focus and Movement", "Layout", "Modes", "Media",
        "Animations and Effects", "Misc Commands", "System",
        "Shell", "Other"
    ]

    // ═══════════════════════════════════════════════════════════════
    // STATE
    // ═══════════════════════════════════════════════════════════════

    property var _hyprlandBinds: []
    property var filteredBindCategories: []
    property var filteredIpcHandlers: []

    // ═══════════════════════════════════════════════════════════════
    // PROCESS — hyprctl -j binds
    // ═══════════════════════════════════════════════════════════════

    Process {
        id: hyprBindsProc
        command: ["hyprctl", "-j", "binds"]

        onExited: (exitCode) => {
            if (exitCode !== 0)
                console.warn("Cheatsheet: hyprctl -j binds failed (exit " + exitCode + ")")
        }

        stdout: StdioCollector {
            onStreamFinished: {
                Qt.callLater(root._processBinds, text)
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
        return map[dispatcher] || ""
    }

    // Categorise by DESCRIPTION when the dispatcher says nothing.
    //
    // Lua binds can expose __lua, HL.Dispatcher(name), or a function address.
    // Their argument is a registry reference, not the original command. Use
    // descriptions for meaning and the factory name only for categorization.
    //
    // The descriptions survive that indirection and are what the user actually
    // reads, so they are the honest key. Rules are ordered: the first match
    // wins, so put the specific ones first ("move window to workspace" before
    // "move window").
    readonly property var _descriptionRules: [
        // Shell-owned features first — these would otherwise look like plain
        // application launches or media keys.
        { re: /cheat ?sheet|dashboard|notification|clipboard|logout|power menu|gaming mode|wallpaper|launcher|screenshot|night ?light|overview|record.*screen|screen.*record|connections|caffeine/, cat: "Shell" },

        { re: /workspace/,                                cat: "Workspaces" },
        { re: /move focus|swap window|move window (left|right|up|down)/, cat: "Focus and Movement" },
        { re: /volume|microphone|mute|track|play\/pause|brightness/, cat: "Media" },
        // Modes BEFORE Window Control: "Resize mode" is a submap, "Resize left"
        // is a window operation, and both contain "resize".
        { re: /\bmode\b|submap/,                          cat: "Modes" },
        { re: /kill|fullscreen|floating|\bresize\b|move window|pin\b|center/, cat: "Window Control" },
        { re: /split|group|layout|pseudo/,                cat: "Layout" },
        { re: /exit|reload|quit/,                         cat: "System" },
        { re: /open |launch |terminal|browser|firefox|file manager|translate/, cat: "Applications" }
    ]

    function categorizeDescription(description) {
        const d = (description || "").toLowerCase()
        if (d === "") return "Other"
        for (const rule of root._descriptionRules) {
            if (rule.re.test(d)) return rule.cat
        }
        return "Other"
    }

    // Direct binds identify the shell by its global-shortcut namespace or IPC
    // executable. Lua binds retain only a description, so ownership there is
    // best-effort; unrelated native global shortcuts stay outside Shell.
    function isShellBind(b) {
        const info = BindFormatting.dispatcherInfo(b.dispatcher)
        if (!info.indirect) {
            if (info.name === "global") return (b.arg || "").startsWith("quickshell:")
            return /(?:^|[\s/])(?:at1ass-shell|shell-ctl)\s+ipc\s+call\s/.test(b.arg || "")
        }
        return categorizeDescription(b.description) === "Shell"
    }

    function _processBinds(jsonText) {
        try {
            const parsed = JSON.parse(jsonText)
            const binds = []
            const shellBinds = []
            for (const b of parsed) {
                const info = BindFormatting.dispatcherInfo(b.dispatcher)
                const execution = BindFormatting.executionText(b)
                if (root.isShellBind(b)) {
                    // Direct form: arg is "quickshell:actionName". Lua form:
                    // arg is an opaque handle, so the action name is unknown
                    // and the description carries the meaning.
                    const action = !info.indirect && info.name === "global"
                        ? (b.arg || "").slice("quickshell:".length) : ""
                    shellBinds.push({
                        type: "shell",
                        modifiers: decodeModmask(b.modmask),
                        key: b.key || ("keycode:" + b.keycode),
                        description: b.description
                            || root._shellDescriptions[action]
                            || action
                            || "(no description)",
                        action: action,
                        execution: execution,
                        submap: b.submap || "",
                        category: "Shell"
                    })
                    continue
                }
                // Native dispatchers are exact. Lua descriptions carry more
                // meaning than the factory name (exec_cmd can control media).
                const byDispatcher = categorizeDispatcher(BindFormatting.categoryDispatcher(info.name))
                const byDescription = root.categorizeDescription(b.description)
                binds.push({
                    type: "hyprland",
                    modifiers: decodeModmask(b.modmask),
                    key: b.key || ("keycode:" + b.keycode),
                    description: b.description || BindFormatting.fallbackDescription(b),
                    dispatcher: info.indirect ? info.name : b.dispatcher,
                    arg: info.indirect ? "" : (b.arg || ""),
                    execution: execution,
                    category: info.indirect && byDescription !== "Other" ? byDescription
                        : (byDispatcher || byDescription),
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
        const query = view.query.toLowerCase().trim()
        const allBinds = _hyprlandBinds.concat(_shellBindsComputed)

        // Filter binds
        const filtered = query.length === 0 ? allBinds : allBinds.filter(b => {
            const desc = (b.description || "").toLowerCase()
            const key = (b.key || "").toLowerCase()
            const dispatcher = (b.dispatcher || "").toLowerCase()
            const arg = (b.arg || "").toLowerCase()
            const action = (b.action || "").toLowerCase()
            const execution = (b.execution || "").toLowerCase()
            const mods = (b.modifiers || []).join(" ").toLowerCase()
            return desc.includes(query) || key.includes(query) ||
                   dispatcher.includes(query) || arg.includes(query) ||
                   action.includes(query) || execution.includes(query) || mods.includes(query)
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

    CheatsheetView {
        id: view
        anchors.fill: parent
        active: GlobalStates.cheatsheetOpen
        categories: root.filteredBindCategories
        handlers: root.filteredIpcHandlers
        loading: Components.IpcReferenceData.busy
        errorMessage: Components.IpcReferenceData.errorMessage
        onQueryChanged: root._applyFilter()
        onCloseRequested: GlobalStates.closePanel("cheatsheet")
        onRetryRequested: Components.IpcReferenceData.refresh()
    }

    Connections {
        target: Components.IpcReferenceData
        function onHandlersChanged() { root._applyFilter() }
    }

    // Reset and fetch on visibility change
    onVisibleChanged: {
        if (visible) {
            view.query = ""
            view.currentTab = 0
            if (!hyprBindsProc.running) hyprBindsProc.running = true
            Components.IpcReferenceData.refresh()
            Qt.callLater(function() {
                view.focusSearch()
            })
        }
    }

    Component.onCompleted: {
        if (!hyprBindsProc.running) hyprBindsProc.running = true
        Components.IpcReferenceData.refresh()
    }

    // A retained panel keeps whatever the user left in it. Reset the query and
    // take focus on every open, so a reopened cheatsheet behaves exactly like a
    // freshly built one -- which is what it used to be.
    Connections {
        target: GlobalStates
        function onPanelOpened(name) {
            if (name !== "cheatsheet")
                return
            view.query = ""
            Components.IpcReferenceData.refresh()
            if (!hyprBindsProc.running) hyprBindsProc.running = true
            view.focusSearch()
        }
    }
}
