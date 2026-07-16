pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.src.core.config

// Centralised Do-Not-Disturb policy.
//
// `enabled` is the user-facing manual toggle (persisted in stateData).
// `active` adds context-awareness — also true when a fullscreen window
// is in focus, matching the caelestia/noctalia behaviour where popups
// don't intrude over a fullscreen video / game / presentation.

Singleton {
    id: root

    // User toggle, persisted via AppConfig stateData
    property bool enabled: AppConfig.stateData?.notifications?.doNotDisturb ?? false
    onEnabledChanged: AppConfig.updateState("notifications", { "doNotDisturb": enabled })

    // Fullscreen detection — Hyprland's lastIpcObject.fullscreen is 0
    // (none), 1 (maximize), 2 (true fullscreen). Treat any non-zero as
    // "user wants no interruptions".
    readonly property bool _fullscreenActive: {
        const tl = Hyprland.activeToplevel
        return (tl?.lastIpcObject.fullscreen ?? 0) > 0
    }

    readonly property bool active: enabled || _fullscreenActive
}
