pragma Singleton

import QtQuick
import Quickshell

// Two-stage rate limiter for notifications.
//
//  Stage 1 — Ingress bucket: bursts beyond `ingressLimit` per second
//            queue up to `maxQueueSize`; overflows are dropped (caller
//            should untrack to release server-side reference).
//  Stage 2 — Popup gate: between accepted ingresses, at most one popup
//            may "open" per `gatePeriodMs` to keep the visual stack
//            from flashing.
//
// Service drives this by calling ingest()/popupShow() and listening for
// signals; the limiter never reaches into NotifData or service state.

Singleton {
    id: root

    // ── Tunables ──────────────────────────────────────────────────
    property int ingressLimit: 20      // tokens per second
    property int maxQueueSize: 32
    property int gatePeriodMs: 350     // min interval between popup opens

    // ── Internal state ────────────────────────────────────────────
    property int  _tokens: ingressLimit
    property var  _ingressQueue: []    // notifications waiting on tokens

    property bool _gateOpen: true
    property var  _gateQueue: []       // {notification, data} pairs

    // ── Outgoing events ──────────────────────────────────────────
    // ingressAccepted fires when a notification has cleared the bucket
    // (either immediately or after queue drain). The receiving service
    // typically defers actual processing via Qt.callLater so the rest of
    // the QML graph (e.g. trackedNotifications listeners) settles first.
    signal ingressAccepted(var notification)

    // ingressDropped fires when the queue is full — caller should
    // notification.tracked = false to release server tracking.
    signal ingressDropped(var notification)

    // popupReady fires when the gate is open for the supplied (notif,
    // data) pair — service should show the popup synchronously.
    signal popupReady(var notification, var data)

    // ── Bucket refill ────────────────────────────────────────────
    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: root._tokens = Math.min(root._tokens + root.ingressLimit, root.ingressLimit)
    }

    // ── Ingress queue drain ───────────────────────────────────────
    Timer {
        interval: 100
        repeat: true
        running: root._ingressQueue.length > 0
        onTriggered: {
            if (root._tokens <= 0 || root._ingressQueue.length === 0) return
            const notif = root._ingressQueue.shift()
            root._tokens--
            root._ingressQueue = root._ingressQueue   // notify listeners
            root.ingressAccepted(notif)
        }
    }

    // ── Gate timer ────────────────────────────────────────────────
    Timer {
        id: gateTimer
        interval: root.gatePeriodMs
        repeat: false
        onTriggered: {
            if (root._gateQueue.length > 0) {
                const item = root._gateQueue.shift()
                root._gateQueue = root._gateQueue
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
        const isCritical = notification.urgency === 2
        if (isCritical || root._tokens > 0) {
            if (!isCritical) root._tokens--
            ingressAccepted(notification)
            return
        }
        if (root._ingressQueue.length < root.maxQueueSize) {
            root._ingressQueue.push(notification)
            root._ingressQueue = root._ingressQueue
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
        root._gateQueue.push({ "notification": notification, "data": data })
        root._gateQueue = root._gateQueue
    }
}
