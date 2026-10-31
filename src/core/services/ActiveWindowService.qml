pragma Singleton

import Quickshell
import Quickshell.Hyprland

Singleton {
    // Native activeToplevel becomes null on an empty workspace. Copying legacy
    // activewindow events into mutable strings kept the previous title alive.
    readonly property string windowTitle: Hyprland.activeToplevel?.title ?? ""
    readonly property string windowClass: Hyprland.activeToplevel?.lastIpcObject.class ?? ""
}
