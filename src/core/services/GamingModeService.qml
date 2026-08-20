pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.src.core.config

Singleton {
    id: root

    property bool gamingModeActive: false
    property var _savedHyprState: ({})
    property bool _gamingModeRestored: false

    Connections {
        target: AppConfig
        function onStateReadyChanged() { root._tryRestoreGamingMode() }
        function onReadyChanged()      { root._tryRestoreGamingMode() }
    }

    function _tryRestoreGamingMode() {
        if (!AppConfig.stateReady || !AppConfig.ready) return
        if (root._gamingModeRestored) return
        root._gamingModeRestored = true

        const gmState = AppConfig.stateData?.gamingMode
        if (!gmState?.active) return

        root._savedHyprState = gmState.savedState || {}
        if (AppConfig.gmDisableAnimations) Tokens.motionFrozen = true
        root._applyHyprlandGaming()
        root.gamingModeActive = true
    }

    // Increments whenever an enable/disable supersedes the running save
    // chain — a stale chain completing after disable used to re-apply
    // gaming keywords and write {active:true} into state.json.
    property int _chainGeneration: 0

    Process {
        id: hyprGetProc
        property var _keys: []
        property int _index: 0
        property int _generation: -1

        stdout: StdioCollector {
            id: hyprGetCollector
            onStreamFinished: {
                if (hyprGetProc._generation !== root._chainGeneration)
                    return   // superseded by a later toggle
                try {
                    const parsed = JSON.parse(text)
                    const key = hyprGetProc._keys[hyprGetProc._index]
                    let saved = Object.assign({}, root._savedHyprState)
                    if (parsed.custom !== undefined)
                        saved[key] = parsed.custom
                    else if (parsed.int !== undefined)
                        saved[key] = parsed.int
                    else if (parsed.set !== undefined)
                        saved[key] = parsed.set ? 1 : 0
                    else
                        saved[key] = parsed.str || ""
                    root._savedHyprState = saved
                } catch (e) {
                    console.warn("Gaming mode: failed to parse hyprctl output:", e)
                }
            }
        }

        // Chain restarts belong in onExited — restarting from
        // onStreamFinished races the process teardown (ban 18 territory).
        onExited: (exitCode) => {
            if (hyprGetProc._generation !== root._chainGeneration)
                return
            if (exitCode !== 0)
                console.warn("Gaming mode: hyprctl getoption failed (exit " + exitCode + ")")
            hyprGetProc._index++
            if (hyprGetProc._index < hyprGetProc._keys.length) {
                hyprGetProc.command = ["hyprctl", "-j", "getoption", hyprGetProc._keys[hyprGetProc._index]]
                hyprGetProc.running = true
            } else {
                root._applyHyprlandGaming()
            }
        }
    }

    Process {
        id: hyprBatchProc
        onExited: (exitCode) => {
            if (exitCode !== 0)
                ToastService.warning("Hyprland batch command failed (exit " + exitCode + ")")
        }
    }

    function toggleGamingMode() {
        if (gamingModeActive)
            disableGamingMode()
        else
            enableGamingMode()
    }

    function enableGamingMode() {
        GlobalStates.closeAllPanels()
        _saveAndApplyHyprland()
        if (AppConfig.gmDisableAnimations) Tokens.motionFrozen = true
        gamingModeActive = true
        ToastService.info("Gaming mode enabled", 2000)
    }

    function disableGamingMode() {
        _chainGeneration++   // cancel any in-flight save chain
        _restoreHyprland()
        Tokens.motionFrozen = false
        gamingModeActive = false
        AppConfig.updateState("gamingMode", { active: false, savedState: {} })
        ToastService.info("Gaming mode disabled", 2000)
    }

    function _saveAndApplyHyprland() {
        const keys = []
        if (AppConfig.gmHyprDisableAnimations) keys.push("animations:enabled")
        if (AppConfig.gmHyprDisableBlur)       keys.push("decoration:blur:enabled")
        if (AppConfig.gmHyprDisableShadows)    keys.push("decoration:shadow:enabled")
        if (AppConfig.gmHyprGaps === 0)        { keys.push("general:gaps_in"); keys.push("general:gaps_out") }
        if (AppConfig.gmHyprRounding === 0)    keys.push("decoration:rounding")

        if (keys.length === 0) {
            gamingModeActive = true
            AppConfig.updateState("gamingMode", { active: true, savedState: {} })
            return
        }

        _savedHyprState = ({})
        _chainGeneration++
        hyprGetProc._generation = _chainGeneration
        hyprGetProc._keys = keys
        hyprGetProc._index = 0
        hyprGetProc.command = ["hyprctl", "-j", "getoption", keys[0]]
        if (!hyprGetProc.running) hyprGetProc.running = true
    }

    function _applyHyprlandGaming() {
        const parts = []
        if (AppConfig.gmHyprDisableAnimations) parts.push("keyword animations:enabled false")
        if (AppConfig.gmHyprDisableBlur)       parts.push("keyword decoration:blur:enabled false")
        if (AppConfig.gmHyprDisableShadows)    parts.push("keyword decoration:shadow:enabled false")
        if (AppConfig.gmHyprGaps === 0)        { parts.push("keyword general:gaps_in 0"); parts.push("keyword general:gaps_out 0") }
        if (AppConfig.gmHyprRounding === 0)    parts.push("keyword decoration:rounding 0")

        if (parts.length > 0) {
            hyprBatchProc.command = ["hyprctl", "--batch", parts.join(";")]
            hyprBatchProc.running = true
        }
        AppConfig.updateState("gamingMode", { active: true, savedState: root._savedHyprState })
    }

    function _restoreHyprland() {
        const saved = _savedHyprState
        if (!saved || Object.keys(saved).length === 0)
            return

        const parts = []
        for (const key in saved) {
            parts.push(`keyword ${key} ${saved[key]}`)
        }

        if (parts.length > 0) {
            hyprBatchProc.command = ["hyprctl", "--batch", parts.join(";")]
            hyprBatchProc.running = true
        }

        _savedHyprState = ({})
    }

}
