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

    // User toggle. Persisted state is the single source of truth: `enabled`
    // only DERIVES from it, setEnabled() only WRITES it. A read-write
    // property with an onChanged persister loops through stateData and
    // destroys its own binding on the first imperative write.
    readonly property bool enabled: AppConfig.stateData?.notifications?.doNotDisturb ?? false

    function setEnabled(on) {
        if (on !== enabled) AppConfig.updateState("notifications", { "doNotDisturb": on })
    }

    function toggle() {
        setEnabled(!enabled)
    }

    // Fullscreen detection: don't interrupt games/videos.
    // focusedWorkspace.hasFullscreen is updated directly by the Hyprland
    // fullscreen event; activeToplevel.lastIpcObject was a connect-time
    // snapshot that never populated for windows opened after shell start.
    readonly property bool _fullscreenActive:
        AppConfig.notificationSuppressOnFullscreen
        && (Hyprland.focusedWorkspace?.hasFullscreen ?? false)

    // NOTE: `active` is a policy answer for NORMAL notifications. Critical
    // urgency bypasses DND entirely — that check lives in
    // NotificationService._admit, because the exemption is about the
    // notification, not about the policy.
    readonly property bool active: enabled || _fullscreenActive
}
