pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.src.core.config

// Two-stage rate limiter for notifications.
//
//  Stage 1 — Ingress bucket: bursts beyond `ingressLimit` per second
//            queue up to `maxQueueSize`; overflows are reported as dropped.
//  Stage 2 — Popup gate: between accepted ingresses, at most one popup
//            may "open" per `gatePeriodMs` to keep the visual stack
//            from flashing.
//
// PURE POLICY. This singleton reports verdicts and nothing else — it never
// touches `tracked`, never calls dismiss/expire, never reaches into NotifData.
// Closing a notification is NotificationService's job exclusively, because a
// close is a message to the client application and only one place should be
// allowed to send it. (The limiter used to set `tracked = false` on overflow,
// which told the app the user had dismissed something they never saw.)

Singleton {
    id: root

    // ── Tunables (notifications.rateLimit.* in config.json) ───────
    readonly property int ingressLimit: AppConfig.notificationIngressPerSecond
    readonly property int maxQueueSize: AppConfig.notificationMaxQueue
    readonly property int gatePeriodMs: AppConfig.notificationPopupIntervalMs
    // The gate drains ~3/s while ingress admits up to 20/s — without a cap a
    // notification storm grows this queue (and the retained objects) without
    // bound while popups get ever staler. Overflow skips the POPUP only; the
    // notification is already ingressed and lands in history regardless.
    readonly property int maxGateQueueSize: AppConfig.notificationMaxPopupQueue

    // ── Internal state ────────────────────────────────────────────
    property int  _tokens: ingressLimit
    property var  _ingressQueue: []    // notifications waiting on tokens

    property bool _gateOpen: true
    property var  _gateQueue: []       // {notification, data} pairs


    // A queued Notification can be destroyed under us (client closed it
    // while waiting) — property access on the dead wrapper throws.
    function _alive(n) {
        try { return n !== null && n !== undefined && n.id !== undefined } catch (e) { return false }
    }

    // Queue writes MUST go through a fresh array. Mutating a `var` property in
    // place and assigning it back to itself (`q.push(x); q = q`) does NOT emit
    // the change signal — the engine short-circuits on reference equality — so
    // the drain Timer's `running: q.length > 0` binding never re-evaluated and
    // the ingress queue never drained: every notification past the token bucket
    // was silently swallowed AND left tracked=true on the server.
    function _push(arr, item) { return arr.concat([item]) }
    function _shifted(arr) { const next = arr.slice(); next.shift(); return next }

    // ── Outgoing events ──────────────────────────────────────────
    // ingressAccepted fires when a notification has cleared the bucket
    // (either immediately or after queue drain). The receiving service
    // typically defers actual processing via Qt.callLater so the rest of
    // the QML graph (e.g. trackedNotifications listeners) settles first.
    signal ingressAccepted(var notification)

    // ingressDropped fires when the queue is full. The service decides what
    // that means for the notification (currently: expire, reason 1).
    signal ingressDropped(var notification)

    // popupReady fires when the gate is open for the supplied (notif,
    // data) pair — service should show the popup synchronously.
    signal popupReady(var notification, var data)

    // popupDropped fires when the gate queue is full. The notification has
    // already been ingressed (so it is in history); only the popup is skipped.
    signal popupDropped(var notification)

    // Apply tighter hot-reloaded limits to queued work as well as new arrivals.
    onIngressLimitChanged: if (_tokens > ingressLimit) _tokens = ingressLimit
    onMaxQueueSizeChanged: {
        if (!_ingressQueue || _ingressQueue.length <= maxQueueSize) return
        const removed = _ingressQueue.slice(maxQueueSize)
        _ingressQueue = _ingressQueue.slice(0,maxQueueSize)
        for (const notification of removed) ingressDropped(notification)
    }
    onMaxGateQueueSizeChanged: {
        if (!_gateQueue || _gateQueue.length <= maxGateQueueSize) return
        const removed = _gateQueue.slice(maxGateQueueSize)
        _gateQueue = _gateQueue.slice(0,maxGateQueueSize)
        for (const entry of removed) popupDropped(entry.notification)
    }

    // ── Bucket refill ────────────────────────────────────────────
    // Runs only while the bucket is actually short. A full bucket refilling to
    // full is a no-op that does not even emit a change signal, so leaving this
    // on `running: true` was a wakeup every second for the life of the session
    // — 86 400 a day to compute a value that was already correct. Depleting the
    // bucket turns the timer on; the refill turns it back off.
    Timer {
        interval: 1000
        repeat: true
        running: root._tokens < root.ingressLimit
        onTriggered: root._tokens = Math.min(root._tokens + root.ingressLimit, root.ingressLimit)
    }

    // ── Ingress queue drain ───────────────────────────────────────
    Timer {
        interval: 100
        repeat: true
        running: root._ingressQueue.length > 0
        onTriggered: {
            if (root._tokens <= 0 || root._ingressQueue.length === 0) return
            const notif = root._ingressQueue[0]
            root._tokens--
            root._ingressQueue = root._shifted(root._ingressQueue)
            if (root._alive(notif)) root.ingressAccepted(notif)
        }
    }

    // ── Gate timer ────────────────────────────────────────────────
    Timer {
        id: gateTimer
        interval: root.gatePeriodMs
        repeat: false
        onTriggered: {
            if (root._gateQueue.length > 0) {
                const item = root._gateQueue[0]
                root._gateQueue = root._shifted(root._gateQueue)
                if (!root._alive(item.notification)) {
                    // Dead entry: keep the gate closed and come back for the
                    // next one, otherwise the queue stalls behind a corpse.
                    gateTimer.restart()
                    return
                }
                gateTimer.restart()  // gate stays closed for another period
                root.popupReady(item.notification, item.data)
            } else {
                root._gateOpen = true
            }
        }
    }

    // ── Public API ────────────────────────────────────────────────

    // Accept a fresh notification. Critical bypasses the bucket.
    // Returns nothing — callers listen for ingressAccepted/ingressDropped.
    function ingest(notification) {
        const isCritical = notification.urgency === NotificationUrgency.Critical
        // Token path only while the queue is EMPTY — a refilled token must
        // not let a fresh notification jump ahead of queued ones.
        if (isCritical || (root._tokens > 0 && root._ingressQueue.length === 0)) {
            if (!isCritical) root._tokens--
            ingressAccepted(notification)
            return
        }
        if (root._ingressQueue.length < root.maxQueueSize) {
            root._ingressQueue = root._push(root._ingressQueue, notification)
            return
        }
        ingressDropped(notification)
    }

    // Request popup display. Fires popupReady immediately if gate is
    // open, else queues until the gate timer ticks.
    function popupShow(notification, data) {
        if (root._gateOpen) {
            root._gateOpen = false
            gateTimer.restart()
            popupReady(notification, data)
            return
        }
        if (root._gateQueue.length >= root.maxGateQueueSize) {
            popupDropped(notification)
            return
        }
        root._gateQueue = root._push(root._gateQueue,
                                     { "notification": notification, "data": data })
    }
}
