pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

Singleton {
    id: root

    // QS 0.3.2 ignores an empty activewindowv2 address instead of clearing its
    // activeToplevel. Keep titles reactive, but honor explicit loss of focus.
    property bool _focusCleared: false
    // Moving the pointer to an empty monitor can emit focusedmon alone while
    // Hyprland keeps the last window focused on the previous monitor.
    readonly property string _windowMonitor: Hyprland.activeToplevel?.monitor?.name ?? ""
    readonly property string _focusedMonitor: Hyprland.focusedMonitor?.name ?? ""
    readonly property HyprlandToplevel activeWindow: !_focusCleared && _focusedMonitor !== ""
        && _windowMonitor === _focusedMonitor ? Hyprland.activeToplevel : null
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
