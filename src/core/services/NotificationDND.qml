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
    readonly property TimedMode _mode: TimedMode { section: "notifications"; enabledKey: "doNotDisturb" }
    readonly property bool enabled: _mode.enabled
    readonly property bool temporary: _mode.temporary
    readonly property real expiresAt: temporary ? _mode.expiresAt : 0
    readonly property string statusText: _mode.statusText
    function init() { _mode.refresh() }
    function setEnabled(on) { _mode.setEnabled(on) }
    function setForMinutes(minutes) { return _mode.start(minutes) }
    function toggle() { setEnabled(!enabled) }

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
