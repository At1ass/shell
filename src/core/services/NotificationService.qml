pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.src.core.config
import qs.src.features.notifications

// NotificationService — thin facade over the notification subsystem.
//
// Responsibilities (everything else lives elsewhere):
//   - Hosts the NotificationServer and the Instantiator that produces a
//     NotifData per tracked notification.
//   - Routes incoming notifications through NotificationRateLimiter
//     (ingress + popup gate) and NotificationDND (suppress check).
//   - Tracks the *internal* id ↔ NotifData mapping for popup callers
//     (dismissActiveNotification etc.) — Quickshell's notification.id is
//     stable but our internal id (history-style hash:ts:n) is what flows
//     through popupRequested signals, so the indirection stays.
//   - Emits popupRequested / popupReplaced / popupDismissRequested for
//     NotificationPopupManager to consume.
//
// History persistence, group expansion, rate-limit math, and DND policy
// are owned by their respective singletons (NotificationHistory,
// NotificationRateLimiter, NotificationDND).

Singleton {
    id: root

    property int defaultExpireTimeout: AppConfig.notificationPopupTimeout

    // ── Outgoing signals (consumed by NotificationPopupManager) ────
    signal popupRequested(var data, var notification)
    signal popupReplaced(string notificationId, var data)
    signal popupDismissRequested(string notificationId)

    // ── Internal indices ──────────────────────────────────────────
    // History-style internal id (contentId:ts:n) → NotifData
    property var _notifDataByInternalId: ({})
    // Notification.id (Quickshell stable) → internal id
    property var _internalIdByNotifId: ({})
    // Notification.id → NotifData (populated by Instantiator onObjectAdded)
    property var _notifDataByNotifId: ({})

    property int _nextEntryId: 1

    // Popup registration — managed by NotificationPopupManager
    property var _activePopupIds: ({})
    function registerPopup(id) { _activePopupIds[id] = true }
    function unregisterPopup(id) { delete _activePopupIds[id] }
    function hasActivePopup(id) { return !!_activePopupIds[id] }

    // ── Server + per-notification wrappers ────────────────────────
    NotificationServer {
        id: notifServer
        keepOnReload: false
        actionsSupported: true
        imageSupported: true
        bodyMarkupSupported: true

        onNotification: (notification) => root._ingestNotification(notification)
    }

    Instantiator {
        id: notifDataInstantiator
        model: notifServer.trackedNotifications
        delegate: NotifData {
            id: notifData
            required property var modelData
            notification: modelData

            // Service watches popup-relevant property changes and emits
            // popupReplaced. Connections is a non-visual QObject; QtObject
            // (NotifData) lacks a default children list, so attach via
            // an explicit property.
            readonly property Connections _serviceWatch: Connections {
                target: modelData
                function onSummaryChanged()  { root._notifDataPropChanged(modelData) }
                function onBodyChanged()     { root._notifDataPropChanged(modelData) }
                function onAppNameChanged()  { root._notifDataPropChanged(modelData) }
                function onUrgencyChanged()  { root._notifDataPropChanged(modelData) }
                function onAppIconChanged()  { root._notifDataPropChanged(modelData) }
                function onImageChanged()    { root._notifDataPropChanged(modelData) }
                function onActionsChanged()  { root._notifDataPropChanged(modelData) }
            }
            onClosed: (reason) => root._onNotifDataClosed(modelData, reason)
        }

        onObjectAdded: (index, object) => {
            if (object?.notification) {
                root._notifDataByNotifId[object.notification.id] = object
            }
        }
        onObjectRemoved: (index, object) => {
            if (object?.notification) {
                delete root._notifDataByNotifId[object.notification.id]
            }
        }
    }

    // ── Rate-limiter event wiring ─────────────────────────────────
    Connections {
        target: NotificationRateLimiter

        function onIngressAccepted(notification) {
            // Defer to give the Instantiator's onObjectAdded a chance to
            // register this notification's NotifData before _showNotification
            // looks it up.
            Qt.callLater(() => root._processNotification(notification))
        }
        function onIngressDropped(notification) {
            // Queue full — release server-side tracking.
            notification.tracked = false
        }
        function onPopupReady(notification, data) {
            root._showNotification(notification, data)
        }
    }

    // ── Notification flow ─────────────────────────────────────────

    function _ingestNotification(notification) {
        // Track immediately so the server keeps the Notification alive
        // through queue and gate. RateLimiter's signals decide what to
        // do next.
        notification.tracked = true
        NotificationRateLimiter.ingest(notification)
    }

    function _processNotification(notification) {
        const data = createData(notification)
        NotificationHistory.add(data)

        if (NotificationDND.active) {
            // History captured the entry; release the server-side ref.
            notification.tracked = false
            return
        }

        // If the same Notification was already pushed and is still tracked,
        // update its existing popup data instead of creating a new one.
        const existingInternalId = _internalIdByNotifId[notification.id]
        if (existingInternalId && _notifDataByInternalId[existingInternalId]) {
            _updateExistingNotification(existingInternalId, notification)
            return
        }

        const duplicateId = _findDuplicatePopup(data.contentId)
        if (duplicateId) {
            popupDismissRequested(duplicateId)
            cleanupNotification(duplicateId)
        }

        NotificationRateLimiter.popupShow(notification, data)
    }

    function _showNotification(notification, data) {
        const notifData = _notifDataByNotifId[notification.id]
        if (!notifData) {
            console.warn("NotificationService: NotifData missing for", notification.id)
            return
        }
        _internalIdByNotifId[notification.id] = data.notificationId
        _notifDataByInternalId[data.notificationId] = notifData
        popupRequested(data, notification)
    }

    function _updateExistingNotification(internalId, notification) {
        const normalized = normalizeNotification(notification)
        const contentId = getContentId(normalized.summary, normalized.body, normalized.appName)

        const updatedData = {
            "notificationId": internalId,
            "contentId": contentId,
            "summary": normalized.summary,
            "body": normalized.body,
            "appName": normalized.appName,
            "appIcon": normalized.appIcon,
            "image": normalized.image,
            "actions": normalized.actions,
            "urgency": normalized.urgency,
            "expireTimeout": normalized.expireTimeout
        }
        popupReplaced(internalId, updatedData)
    }

    function _notifDataPropChanged(notification) {
        const internalId = _internalIdByNotifId[notification.id]
        if (!internalId) return
        if (!_notifDataByInternalId[internalId]) return
        _updateExistingNotification(internalId, notification)
    }

    function _onNotifDataClosed(notification, reason) {
        const internalId = _internalIdByNotifId[notification.id]
        if (!internalId) return
        // Dismissed (2): user already triggered dismiss path.
        // Expired (1) / CloseRequested (3): popup must still exit.
        if (hasActivePopup(internalId) && reason !== 2) {
            popupDismissRequested(internalId)
        }
        // Tag history with close reason (best-effort; entry may already be pruned).
        NotificationHistory.tagCloseReason(internalId, reason)
        cleanupNotification(internalId)
    }

    function _findDuplicatePopup(contentId) {
        for (const id in _activePopupIds) {
            const nd = _notifDataByInternalId[id]
            if (nd && nd.contentId === contentId) return id
        }
        return null
    }

    function cleanupNotification(id) {
        const nd = _notifDataByInternalId[id]
        if (!nd) return
        const notifId = nd.notification?.id
        delete _notifDataByInternalId[id]
        if (notifId !== undefined) delete _internalIdByNotifId[notifId]
    }

    // ── Data shaping ──────────────────────────────────────────────

    function normalizeNotification(notification) {
        const summary = (notification.summary || "").trim()
        // Body passes through unchanged; bodyMarkupSupported=true means
        // clients send text suitable for Text.StyledText rendering.
        const body = notification.body || ""
        const appName = (notification.appName || notification.desktopEntry || "").trim()
        const appIcon = notification.appIcon || ""
        const image = notification.image || ""
        const urgency = (notification.urgency < 0 || notification.urgency > 2)
            ? NotificationUrgency.Normal
            : notification.urgency
        const expireTimeout = typeof notification.expireTimeout === "number"
            ? notification.expireTimeout
            : -1
        const actions = (notification.actions || []).map((action) => ({
            "identifier": action.identifier || "",
            "text": action.text || ""
        }))
        return {
            "summary": summary, "body": body, "appName": appName,
            "appIcon": appIcon, "image": image, "actions": actions,
            "urgency": urgency, "expireTimeout": expireTimeout
        }
    }

    function createData(notification) {
        const normalized = normalizeNotification(notification)
        const timestamp = Date.now()
        const contentId = getContentId(normalized.summary, normalized.body, normalized.appName)
        const notificationId = contentId + ":" + timestamp.toString(16) + ":" + (_nextEntryId++)
        return Object.assign({
            "id": notificationId,
            "notificationId": notificationId,
            "contentId": contentId,
            "timestamp": timestamp
        }, normalized)
    }

    function getContentId(summary, body, appName) {
        return _hash(summary + "\n" + body + "\n" + appName)
    }

    function _hash(str) {
        let hash = 0
        for (let i = 0; i < str.length; i++) {
            hash = ((hash << 5) - hash) + str.charCodeAt(i)
            hash |= 0
        }
        return (hash >>> 0).toString(16)
    }

    // ── Hover delegation ──────────────────────────────────────────
    // Single source of truth lives on NotifData; service just routes by id.
    function incrementHover(id) {
        const nd = _notifDataByInternalId[id]
        if (nd) nd.pauseTimeout()
    }
    function decrementHover(id) {
        const nd = _notifDataByInternalId[id]
        if (nd) nd.resumeTimeout()
    }
    // Backward-compatible aliases
    function pauseTimeout(id) { incrementHover(id) }
    function resumeTimeout(id) { decrementHover(id) }

    // ── Public API ────────────────────────────────────────────────
    //
    // dismissActiveNotification / expireActiveNotification:
    //   dismiss() → server fires closed(Dismissed=2). Use for X-button,
    //   swipe, action click.
    //   expire() → server fires closed(Expired=1). Use for the auto-
    //   dismiss timer in NotificationPopupItem.

    function dismissActiveNotification(id) {
        const nd = _notifDataByInternalId[id]
        nd?.dismiss()
        cleanupNotification(id)
        popupDismissRequested(id)
    }
    function expireActiveNotification(id) {
        const nd = _notifDataByInternalId[id]
        nd?.expire()
        cleanupNotification(id)
        popupDismissRequested(id)
    }

    function dismissAllActive() {
        const ids = Object.keys(_activePopupIds)
        for (const id of ids) dismissActiveNotification(id)
    }

    function attemptInvokeAction(id, actionId) {
        const nd = _notifDataByInternalId[id]
        if (!nd) return
        nd.invokeAction(actionId)   // also dismisses
        cleanupNotification(id)
        popupDismissRequested(id)
    }

    function activeDuration(id) {
        const nd = _notifDataByInternalId[id]
        return nd ? nd.durationMs : 0
    }

    // ── History delegations (kept for legacy UI calls) ────────────
    function removeFromHistory(id)  { return NotificationHistory.remove(id) }
    function clearHistory()         { NotificationHistory.clear() }
    function isGroupExpanded(name)  { return NotificationHistory.isGroupExpanded(name) }
    function toggleGroupExpanded(n) { NotificationHistory.toggleGroupExpanded(n) }
    function getGroupCount(name)    { return NotificationHistory.getGroupCount(name) }
    function getGroupIcon(name)     { return NotificationHistory.getGroupIcon(name) }
    readonly property var historyList: NotificationHistory.historyList

    // DND delegate (NotificationCenter toggles via this property).
    // Bidirectional sync with NotificationDND.enabled — direct assignment
    // breaks the initial binding, so Connections re-syncs on external changes.
    property bool doNotDisturb: NotificationDND.enabled
    onDoNotDisturbChanged: {
        if (NotificationDND.enabled !== doNotDisturb) NotificationDND.enabled = doNotDisturb
    }
    Connections {
        target: NotificationDND
        function onEnabledChanged() {
            if (root.doNotDisturb !== NotificationDND.enabled) {
                root.doNotDisturb = NotificationDND.enabled
            }
        }
    }

    // ── Compatibility wrappers (kept for any external IPC) ────────
    function discardNotification(id) { dismissActiveNotification(id) }
    function discardAllNotifications() {
        dismissAllActive()
        clearHistory()
    }
}
