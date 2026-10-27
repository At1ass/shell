pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

// Every dispatch the shell issues, in one place.
//
// Hyprland 0.56 moved dispatching to Lua and dropped the string form: the
// compositor now wraps whatever arrives on the IPC socket as
// `return hl.dispatch(<text>)`, so the old `dispatch workspace 2` became
// `return hl.dispatch(workspace 2)` — a Lua syntax error. Every call site in
// the shell silently stopped working: bar workspace switching (click and
// scroll), the workspace widget's per-window icons, the dock's focus and
// close, and logout. Verified over the raw socket: all string forms return
// `')' expected near ...`, and quoting the whole string instead returns
// `hl.dispatch: expected a dispatcher`.
//
// The working form sends only the dispatcher EXPRESSION and lets Hyprland
// supply the `hl.dispatch(...)` around it. That syntax lives here alone, so
// the next compositor change is one file, not five call sites.
Singleton {
    id: root

    // Arguments are interpolated into a Lua expression, so they are validated
    // the same way argv is before hitting a shell: an id must be an integer
    // and an address must look like one. Both come from Hyprland itself
    // today, which is exactly the assumption that stops being true the moment
    // a config value or a stale model entry reaches one of these.
    function _isId(v)      { return Number.isInteger(v) && v > -100000 && v < 100000 }
    function _isAddress(a) { return typeof a === "string" && /^0x[0-9a-fA-F]+$/.test(a) }

    // Hyprland reports toplevel addresses both with and without the 0x that
    // its own window selectors require.
    function _addr(a) {
        if (typeof a !== "string" || a === "") return ""
        return a.startsWith("0x") ? a : "0x" + a
    }

    function _workspace(id, name) {
        if (!root._isId(id) || id === 0) return ""
        if (id > 0 || !name) return String(id)
        if (typeof name !== "string" || name.length > 256 || /[\x00-\x1f\x7f]/.test(name)) return ""
        const selector = name.startsWith("special:") ? name : "name:" + name
        return '"' + selector.replace(/\\/g, "\\\\").replace(/"/g, '\\"') + '"'
    }
    function moveWindowToWorkspace(address, id, name) {
        const a = root._addr(address)
        const workspace = root._workspace(id, name)
        if (!root._isAddress(a) || !workspace) return false
        Hyprland.dispatch(`hl.dsp.window.move({window="address:${a}",workspace=${workspace},follow=false})`)
        return true
    }
    function focusWorkspace(id, name) {
        if (!root._isId(id)) {
            console.warn("HyprlandDispatch: refusing non-integer workspace id:", id)
            return
        }
        const workspace = root._workspace(id, name)
        if (workspace) Hyprland.dispatch(`hl.dsp.focus({workspace=${workspace}})`)
    }

    function focusWindow(address) {
        const a = root._addr(address)
        if (!root._isAddress(a)) {
            console.warn("HyprlandDispatch: refusing malformed window address:", address)
            return
        }
        Hyprland.dispatch(`hl.dsp.focus({window="address:${a}"})`)
    }

    function closeWindow(address) {
        const a = root._addr(address)
        if (!root._isAddress(a)) {
            console.warn("HyprlandDispatch: refusing malformed window address:", address)
            return
        }
        Hyprland.dispatch(`hl.dsp.window.close({window="address:${a}"})`)
    }

    function exitCompositor() {
        Hyprland.dispatch("hl.dsp.exit()")
    }
}
