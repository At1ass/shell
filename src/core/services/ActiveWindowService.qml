pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

Singleton {
    id: root

    // QS 0.3.2 ignores an empty activewindowv2 address instead of clearing its
    // activeToplevel. Keep titles reactive, but honor explicit loss of focus.
    property bool _focusCleared: false
    readonly property HyprlandToplevel activeWindow: _focusCleared ? null : Hyprland.activeToplevel
    readonly property string windowTitle: activeWindow?.title ?? ""
    readonly property string windowClass: activeWindow?.lastIpcObject.class ?? ""

    // Start observing before lazy bar widgets are enabled or recreated.
    function init() {}

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name !== "activewindowv2") return
            const address = event.data.trim().replace(/^0x/i, "")
            if (address !== "" && !/^[0-9a-f]{1,16}$/i.test(address)) return
            root._focusCleared = address === "" || /^0+$/.test(address)
        }
    }
}
