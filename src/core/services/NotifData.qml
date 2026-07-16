pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.Notifications
import qs.src.core.config

// Reactive wrapper around a single Notification. Lifetime is governed by
// the Instantiator that creates these (see NotificationService) — when the
// underlying notification is removed from the server's trackedNotifications,
// the delegate (this NotifData) is destroyed automatically. No manual
// createObject/destroy.
//
// Holds:
//  - Derived properties (contentId, durationMs)
//  - Hover/pause counters used by NotificationPopupItem
//  - Connections that translate the Notification's `closed(reason)` into a
//    NotifData-level `closed(reason)` signal, so consumers don't have to
//    chase the underlying Notification (which Quickshell may already have
//    discarded by the time the signal fires).

QtObject {
    id: data

    required property Notification notification

    // ── Stable identity ────────────────────────────────────────────────
    readonly property string contentId: _hash(
        (notification?.summary || "") + "\n"
        + (notification?.body || "") + "\n"
        + (notification?.appName || notification?.desktopEntry || "")
    )

    readonly property int notificationServerId: notification?.id ?? 0

    // Captured at construction so it doesn't drift when the user hovers.
    readonly property real timestamp: Date.now()

    // ── Computed display duration ──────────────────────────────────────
    readonly property int durationMs: {
        if (!notification) return 0
        const t = notification.expireTimeout
        if (t === 0) return -1   // persistent (per spec, app intent)
        if (t > 0)   return t    // app-specified, in ms
        switch (notification.urgency) {
            case 0: return AppConfig.notificationTimeoutLow
            case 2: return AppConfig.notificationTimeoutCritical
            default: return AppConfig.notificationTimeoutNormal
        }
    }

    // ── Hover / pause state ────────────────────────────────────────────
    // Single source of truth — PopupItem reads/writes via pauseTimeout/resume.
    property int hoverCount: 0
    property real pauseStartedAt: 0
    property real displayPauseAccumulated: 0

    function pauseTimeout() {
        if (hoverCount === 0) pauseStartedAt = Date.now()
        hoverCount++
    }
    function resumeTimeout() {
        if (hoverCount <= 0) return
        hoverCount--
        if (hoverCount === 0) {
            displayPauseAccumulated += Date.now() - pauseStartedAt
        }
    }

    // ── Close lifecycle ────────────────────────────────────────────────
    // closeReason is set when the underlying notification's closed(reason)
    // fires. Consumers connect to this NotifData's `closed` signal — by the
    // time the underlying Notification has been freed, this NotifData may
    // still exist briefly until its own Component.onDestruction runs.
    property int closeReason: -1
    signal closed(int reason)

    // ── Imperative accessors (delegate to Notification) ────────────────
    function dismiss() {
        if (notification?.dismiss) notification.dismiss()
    }
    function expire() {
        if (notification?.expire) notification.expire()
    }
    function invokeAction(actionId) {
        const actions = notification?.actions
        if (!actions) return
        for (const a of actions) {
            if (a.identifier === actionId && a.invoke) {
                a.invoke()
                break
            }
        }
        // Per freedesktop spec, the server closes a non-resident notification
        // automatically once an action is invoked — calling dismiss() here
        // would race with the synchronous tear-down of this NotifData
        // (Instantiator destroys the delegate when the notification leaves
        // trackedNotifications, which can happen mid-invoke).
    }

    function _hash(s) {
        let h = 0
        for (let i = 0; i < s.length; i++) {
            h = ((h << 5) - h) + s.charCodeAt(i)
            h |= 0
        }
        return (h >>> 0).toString(16)
    }

    // Connections is a non-visual QObject. QtObject doesn't expose a
    // default children list, so attach via an explicit property — same
    // declarative auto-disconnect, no manual cleanup.
    readonly property Connections _conn: Connections {
        target: data.notification
        function onClosed(reason) {
            data.closeReason = reason
            data.closed(reason)
        }
    }
}
