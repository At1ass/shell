pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

// Popout coordination as DATA, not instance handles. Consumers (e.g. the
// tray widget) write a request here; the Popouts window observes it and
// renders. Nothing outside features/popouts ever touches the window object,
// so a disabled/unloaded popouts module degrades to a harmless no-op.
Singleton {
    id: root

    // ── Request (written by consumers) ──────────────────────────────
    // "" = no popout. `data` and `sourceItem` are QObject/Item-typed on
    // purpose: QML auto-nulls them when the underlying object is destroyed
    // (tray app quits, bar widget unloads) — no dangling handles.
    property string name: ""
    property QtObject data: null
    property Item sourceItem: null

    readonly property bool open: name !== ""

    // Bumped on every open/close so the renderer can react to a re-open of
    // the same popout (screen change, grab re-arm) without extra plumbing.
    property int epoch: 0

    // ── Rendered geometry (written by the Popouts window) ───────────
    property string screenName: ""
    property real popoutX: 0
    property real popoutY: 0
    property real popoutWidth: 0
    property real popoutHeight: 0

    function openPopout(popoutName, popoutData, source) {
        if (!popoutName)
            return
        // Toggle: requesting the same popout from the same source closes it.
        if (open && name === popoutName && sourceItem === source) {
            closePopout()
            return
        }
        name = popoutName
        data = popoutData ?? null
        sourceItem = source ?? null
        epoch++
    }

    function closePopout() {
        if (!open)
            return
        name = ""
        data = null
        sourceItem = null
        screenName = ""
        popoutX = 0
        popoutY = 0
        popoutWidth = 0
        popoutHeight = 0
        epoch++
    }

    function setPopoutRect(x, y, w, h, targetScreenName) {
        popoutX = x || 0
        popoutY = y || 0
        popoutWidth = w || 0
        popoutHeight = h || 0
        screenName = targetScreenName || ""
    }
}
