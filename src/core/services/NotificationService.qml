pragma Singleton

import QtQuick
import QtCore
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs.src.core.config
import qs.src.features.notifications

Singleton {
    id: root

    // Configuration
    property int maxVisible: AppConfig.notificationPopupMaxVisible
    property int maxHistory: 200
    property int defaultExpireTimeout: AppConfig.notificationPopupTimeout
    property bool doNotDisturb: AppConfig.stateData?.notifications?.doNotDisturb ?? false

    onDoNotDisturbChanged: AppConfig.updateState("notifications", { "doNotDisturb": doNotDisturb })

    // Popup signals — consumed by NotificationPopupManager
    signal popupRequested(var data, var notification)
    signal popupReplaced(string notificationId, var data)
    signal popupDismissRequested(string notificationId)

    // State
    property ListModel historyList: ListModel {}

    // Maps internal id (history-style, "contentId:ts:n") to the NotifData
    // wrapper. NotifData lifetime is governed by the Instantiator below;
    // this map is a lookup for QML callers that hold the internal id.
    property var _notifDataByInternalId: ({})

    // Reverse map: Notification.id (Quickshell stable id) -> internal id.
    // Used to detect "same notification pushed again" so we can update
    // instead of re-creating.
    property var _internalIdByNotifId: ({})

    // NotifData index by Quickshell's stable Notification.id. Populated
    // synchronously by the Instantiator delegate's Component.onCompleted —
    // by the time _processNotification runs, the delegate exists.
    property var _notifDataByNotifId: ({})

    property int _nextEntryId: 1

    // Popup registration — managed by PopupManager
    property var _activePopupIds: ({})

    function registerPopup(id) { _activePopupIds[id] = true }
    function unregisterPopup(id) { delete _activePopupIds[id] }
    function hasActivePopup(id) { return !!_activePopupIds[id] }

    // Rate limiting: token bucket
    property int _maxIngressPerSecond: 20
    property int _rateBucketTokens: 20
    property int _maxQueueSize: 32
    property var _notificationQueue: []

    // Gate mechanism: 350ms cooldown between successive popup displays
    property var _gateQueue: []
    property bool _gateOpen: true

    // Batch dismissal
    property var _batchDismissQueue: []
    property var _batchHistoryClearQueue: []

    // Group expansion state (appName -> bool)
    property var _expandedGroups: ({})
    property int _groupVersion: 0

    // Persistent history
    readonly property string historyFile: StandardPaths.writableLocation(StandardPaths.ConfigLocation) + "/quickshell/notification-history.json"

    NotificationServer {
        id: notifServer
        keepOnReload: false
        actionsSupported: true
        imageSupported: true
        // UI components render body as Text.StyledText — declare markup
        // support so clients know they can send HTML-style markup, and
        // we don't have to strip tags (which broke "Less than < 5").
        bodyMarkupSupported: true

        onNotification: (notification) => {
            root._ingestNotification(notification)
        }
    }

    // One NotifData per tracked notification. The Instantiator's lifetime
    // tracks the server's trackedNotifications ObjectModel — when a
    // notification is removed (because tracked=false or it closes), the
    // delegate is destroyed automatically. Replaces the previous pattern of
    // dynamically creating Connections via notificationWatcherComponent and
    // remembering to destroy them.
    Instantiator {
        id: notifDataInstantiator
        model: notifServer.trackedNotifications
        delegate: NotifData {
            id: notifData
            required property var modelData
            notification: modelData

            // Service watches popup-relevant property changes and emits
            // popupReplaced so the active popup can update. Attach via an
            // explicit property — QtObject has no default children list.
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

        // Register/unregister on Instantiator add/remove — guaranteed to
        // fire after the delegate is fully constructed and before the
        // next event-loop iteration processes our deferred _processNotification.
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

    // Rate limit bucket refill
    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: {
            root._rateBucketTokens = Math.min(root._rateBucketTokens + root._maxIngressPerSecond, root._maxIngressPerSecond)
        }
    }

    // Rate limit queue drain
    Timer {
        id: queueDrainTimer
        interval: 100
        repeat: true
        running: root._notificationQueue.length > 0
        onTriggered: {
            if (root._rateBucketTokens > 0 && root._notificationQueue.length > 0) {
                const notification = root._notificationQueue.shift()
                root._rateBucketTokens--
                root._processNotification(notification)
                root._notificationQueue = root._notificationQueue // trigger change signal
            }
        }
    }

    // Gate timer: 350ms cooldown between popup displays
    Timer {
        id: gateTimer
        interval: 350
        repeat: false
        onTriggered: {
            root._gateOpen = true
            root._drainGate()
        }
    }

    // Batch dismissal timer
    Timer {
        id: batchDismissTimer
        interval: 8
        repeat: true
        running: root._batchDismissQueue.length > 0
        onTriggered: {
            const batch = root._batchDismissQueue.splice(0, 8)
            for (const id of batch) root.dismissActiveNotification(id)
            root._batchDismissQueue = root._batchDismissQueue
        }
    }

    // Batch history clear timer
    Timer {
        id: batchHistoryClearTimer
        interval: 8
        repeat: true
        running: root._batchHistoryClearQueue.length > 0
        onTriggered: {
            const count = Math.min(8, root._batchHistoryClearQueue.length)
            for (let i = 0; i < count; i++) {
                const idx = root._batchHistoryClearQueue.shift()
                if (idx < historyList.count) historyList.remove(idx)
            }
            root._batchHistoryClearQueue = root._batchHistoryClearQueue
            if (root._batchHistoryClearQueue.length === 0) saveHistory()
        }
    }

    Component.onCompleted: {
        historyFileView.reload()
    }

    function _ingestNotification(notification) {
        // Track immediately so the server keeps the Notification alive while
        // we decide what to do — otherwise notifications routed through the
        // queue would be discarded between push and drain.
        notification.tracked = true

        const isCritical = notification.urgency === 2 // NotificationUrgency.Critical
        if (isCritical || root._rateBucketTokens > 0) {
            if (!isCritical) root._rateBucketTokens--
            // Defer one event-loop tick so the Instantiator's delegate
            // for this newly-tracked notification has time to register in
            // _notifDataByNotifId before _showNotification looks it up.
            Qt.callLater(() => root._processNotification(notification))
        } else if (root._notificationQueue.length < root._maxQueueSize) {
            root._notificationQueue.push(notification)
            root._notificationQueue = root._notificationQueue // trigger change signal
        } else {
            // Queue full — explicit untrack discards via the server.
            notification.tracked = false
        }
    }

    function _processNotification(notification) {
        // Build history entry from current values; data is value-copy, so it
        // outlives the Notification object even if we untrack it below.
        const data = createData(notification)
        addToHistory(data)

        if (doNotDisturb) {
            // Untrack to discard — history already captured the values.
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

        _gateShow(notification.id, notification, data)
    }

    function _gateShow(quickshellId, notification, data) {
        if (root._gateOpen) {
            root._gateOpen = false
            gateTimer.restart()
            _showNotification(quickshellId, notification, data)
        } else {
            root._gateQueue.push({ "quickshellId": quickshellId, "notification": notification, "data": data })
            root._gateQueue = root._gateQueue
        }
    }

    function _drainGate() {
        if (root._gateQueue.length === 0) return
        const item = root._gateQueue.shift()
        root._gateQueue = root._gateQueue
        root._gateOpen = false
        gateTimer.restart()
        _showNotification(item.quickshellId, item.notification, item.data)
    }

    function _showNotification(quickshellId, notification, data) {
        const notifData = _notifDataByNotifId[quickshellId]
        if (!notifData) {
            // Should not happen — Instantiator's Component.onCompleted runs
            // synchronously when trackedNotifications gains an entry. Defensive.
            console.warn("NotificationService: NotifData missing for tracked notification", quickshellId)
            return
        }

        _internalIdByNotifId[quickshellId] = data.notificationId
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

    // Called by the Instantiator's per-NotifData Connections when a notable
    // property of the Notification changes — translate to a popupReplaced
    // signal so the active popup re-renders with new content.
    function _notifDataPropChanged(notification) {
        const internalId = _internalIdByNotifId[notification.id]
        if (!internalId) return
        if (!_notifDataByInternalId[internalId]) return
        _updateExistingNotification(internalId, notification)
    }

    // Called when a NotifData's underlying Notification fires closed(reason).
    // Translate to internal-id-based dismiss signal; the NotifData itself
    // will be destroyed by the Instantiator shortly after.
    function _onNotifDataClosed(notification, reason) {
        const internalId = _internalIdByNotifId[notification.id]
        if (!internalId) return
        // For Dismissed (2): user already triggered dismiss path — popup
        // exit is in flight via dismissActiveNotification's popupDismissRequested.
        // For Expired (1) / CloseRequested (3): still need to dismiss popup if visible.
        if (hasActivePopup(internalId) && reason !== 2 /* Dismissed */) {
            popupDismissRequested(internalId)
        }
        cleanupNotification(internalId)
    }

    function _findDuplicatePopup(contentId) {
        for (const id in root._activePopupIds) {
            const nd = _notifDataByInternalId[id]
            if (nd && nd.contentId === contentId) {
                return id
            }
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

    function calculateDuration(data) {
        if (data.expireTimeout === 0) return -1   // persistent
        if (data.expireTimeout > 0) return data.expireTimeout  // app-specified
        // Per-urgency defaults
        switch (data.urgency) {
            case 0: return AppConfig.notificationTimeoutLow       // Low
            case 2: return AppConfig.notificationTimeoutCritical   // Critical
            default: return AppConfig.notificationTimeoutNormal    // Normal
        }
    }

    function normalizeNotification(notification) {
        const summary = (notification.summary || "").trim()
        // body passed through unchanged — server advertises bodyMarkupSupported,
        // so clients send HTML-style markup which UI renders via Text.StyledText.
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
            "summary": summary,
            "body": body,
            "appName": appName,
            "appIcon": appIcon,
            "image": image,
            "actions": actions,
            "urgency": urgency,
            "expireTimeout": expireTimeout
        }
    }

    function createData(notification) {
        const normalized = normalizeNotification(notification)
        const timestamp = Date.now()
        const contentId = getContentId(normalized.summary, normalized.body, normalized.appName)
        const notificationId = contentId + ":" + timestamp.toString(16) + ":" + (_nextEntryId++)

        return {
            "id": notificationId,
            "notificationId": notificationId,
            "contentId": contentId,
            "summary": normalized.summary,
            "body": normalized.body,
            "appName": normalized.appName,
            "appIcon": normalized.appIcon,
            "image": normalized.image,
            "actions": normalized.actions,
            "urgency": normalized.urgency,
            "expireTimeout": normalized.expireTimeout,
            "timestamp": timestamp
        }
    }

    function getContentId(summary, body, appName) {
        const raw = summary + "\n" + body + "\n" + appName
        return hashString(raw)
    }

    function hashString(str) {
        let hash = 0
        for (let i = 0; i < str.length; i++) {
            hash = ((hash << 5) - hash) + str.charCodeAt(i)
            hash |= 0
        }
        return (hash >>> 0).toString(16)
    }

    // Hover/pause delegated to NotifData (single source of truth).
    function incrementHover(id) {
        const nd = _notifDataByInternalId[id]
        if (nd) nd.pauseTimeout()
    }

    function decrementHover(id) {
        const nd = _notifDataByInternalId[id]
        if (nd) nd.resumeTimeout()
    }

    // Backward-compatible wrappers (callers in QML still use these names).
    function pauseTimeout(id) { incrementHover(id) }
    function resumeTimeout(id) { decrementHover(id) }

    // History persistence
    FileView {
        id: historyFileView
        path: historyFile
        printErrors: false
        onLoaded: loadHistory()
        onLoadFailed: error => {
            if (error === 2) {
                writeAdapter()
            }
        }

        JsonAdapter {
            id: historyAdapter
            property var notifications: []
        }
    }

    Timer {
        id: saveHistoryTimer
        interval: 200
        repeat: false
        onTriggered: performSaveHistory()
    }

    function saveHistory() {
        saveHistoryTimer.restart()
    }

    function performSaveHistory() {
        try {
            const items = []
            for (var i = 0; i < historyList.count; i++) {
                const entry = historyList.get(i)
                items.push({
                    "notificationId": entry.notificationId,
                    "summary": entry.summary,
                    "body": entry.body,
                    "appName": entry.appName,
                    "appIcon": entry.appIcon,
                    "image": entry.image,
                    "actions": entry.actions || [],
                    "urgency": entry.urgency,
                    "expireTimeout": entry.expireTimeout,
                    "timestamp": entry.timestamp
                })
            }
            historyAdapter.notifications = items
            historyFileView.writeAdapter()
        } catch (e) {
            console.warn("NotificationService: failed to save history", e)
        }
    }

    function pruneHistory() {
        const ttl = AppConfig.notificationHistoryTTLDays
        if (ttl <= 0) return
        const cutoff = Date.now() - (ttl * 24 * 60 * 60 * 1000)
        let removed = false
        for (let i = historyList.count - 1; i >= 0; i--) {
            if ((historyList.get(i).timestamp || 0) < cutoff) {
                historyList.remove(i)
                removed = true
            }
        }
        if (removed) saveHistory()
    }

    Timer {
        interval: 60 * 60 * 1000
        repeat: true
        running: true
        onTriggered: root.pruneHistory()
    }

    function loadHistory() {
        try {
            historyList.clear()
            const ttl = AppConfig.notificationHistoryTTLDays
            const cutoff = ttl > 0 ? Date.now() - (ttl * 24 * 60 * 60 * 1000) : 0
            const allItems = historyAdapter.notifications || []
            const items = cutoff > 0 ? allItems.filter(i => (i.timestamp || 0) >= cutoff) : allItems

            if (AppConfig.notificationGroupByApp) {
                // Build grouped structure for sorted insertion
                const groups = {}
                const groupOrder = []
                for (const item of items) {
                    const appName = item.appName || "Unknown"
                    if (!groups[appName]) {
                        groups[appName] = []
                        groupOrder.push(appName)
                    }
                    groups[appName].push(item)
                }
                // Sort groups by latest timestamp
                groupOrder.sort((a, b) => {
                    const aMax = Math.max(...groups[a].map(i => i.timestamp || 0))
                    const bMax = Math.max(...groups[b].map(i => i.timestamp || 0))
                    return bMax - aMax
                })
                // Insert grouped: each group's items sorted by timestamp desc
                for (const name of groupOrder) {
                    groups[name].sort((a, b) => (b.timestamp || 0) - (a.timestamp || 0))
                    for (const item of groups[name]) {
                        historyList.append({
                            "notificationId": item.notificationId || item.id || "",
                            "id": item.notificationId || item.id || "",
                            "summary": item.summary || "",
                            "body": item.body || "",
                            "appName": item.appName || "",
                            "appIcon": item.appIcon || "",
                            "image": item.image || "",
                            "actions": item.actions || [],
                            "urgency": item.urgency < 0 || item.urgency > 2 ? NotificationUrgency.Normal : item.urgency,
                            "expireTimeout": item.expireTimeout,
                            "timestamp": item.timestamp || 0
                        })
                    }
                }
            } else {
                for (const item of items) {
                    historyList.append({
                        "notificationId": item.notificationId || item.id || "",
                        "id": item.notificationId || item.id || "",
                        "summary": item.summary || "",
                        "body": item.body || "",
                        "appName": item.appName || "",
                        "appIcon": item.appIcon || "",
                        "image": item.image || "",
                        "actions": item.actions || [],
                        "urgency": item.urgency < 0 || item.urgency > 2 ? NotificationUrgency.Normal : item.urgency,
                        "expireTimeout": item.expireTimeout,
                        "timestamp": item.timestamp || 0
                    })
                }
            }
        } catch (e) {
            console.warn("NotificationService: failed to load history", e)
        }
    }

    function addToHistory(data) {
        if (AppConfig.notificationGroupByApp) {
            _sortedInsertHistory(data)
        } else {
            historyList.insert(0, data)
        }
        while (historyList.count > maxHistory) {
            historyList.remove(historyList.count - 1)
        }
        saveHistory()
    }

    function _sortedInsertHistory(data) {
        const appName = data.appName || "Unknown"
        let groupStartIdx = -1
        let groupEndIdx = -1
        for (var i = 0; i < historyList.count; i++) {
            const item = historyList.get(i)
            if ((item.appName || "Unknown") === appName) {
                if (groupStartIdx < 0) groupStartIdx = i
                groupEndIdx = i
            } else if (groupStartIdx >= 0) {
                break // past the group
            }
        }

        if (groupStartIdx < 0) {
            historyList.insert(0, data)
        } else if (groupStartIdx === 0) {
            historyList.insert(0, data)
        } else {
            historyList.insert(0, data)
            const count = groupEndIdx - groupStartIdx + 1
            for (let j = 0; j < count; j++) {
                historyList.move(groupStartIdx + 1 + j, 1 + j, 1)
            }
        }
    }

    // Grouping state for ListView sections
    function isGroupExpanded(appName) {
        // _groupVersion >= 0 is always true, but reading it creates a
        // binding dependency so callers re-evaluate when it increments.
        return root._groupVersion >= 0 && root._expandedGroups[appName] !== false
    }

    function toggleGroupExpanded(appName) {
        root._expandedGroups[appName] = !(root._expandedGroups[appName] !== false)
        root._groupVersion++
    }

    function getGroupCount(appName) {
        let count = 0
        for (var i = 0; i < historyList.count; i++) {
            if ((historyList.get(i).appName || "") === appName) count++
        }
        return count
    }

    function getGroupIcon(appName) {
        for (var i = 0; i < historyList.count; i++) {
            const item = historyList.get(i)
            if ((item.appName || "") === appName) return item.appIcon || ""
        }
        return ""
    }

    // Public API
    //
    // dismiss vs expire (NotificationCloseReason):
    //   - dismissActiveNotification → notification.dismiss() — fires Dismissed (2).
    //     Use when the user explicitly closes (X button, swipe, action click).
    //   - expireActiveNotification → notification.expire() — fires Expired (1).
    //     Use when the auto-dismiss timer ran out.
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
        const ids = Object.keys(root._activePopupIds)
        root._batchDismissQueue = ids
    }

    function removeFromHistory(id) {
        for (var i = 0; i < historyList.count; i++) {
            if (historyList.get(i).notificationId === id) {
                historyList.remove(i)
                saveHistory()
                return true
            }
        }
        return false
    }

    function clearHistory() {
        if (historyList.count <= 16) {
            historyList.clear()
            saveHistory()
        } else {
            const indices = []
            for (var i = historyList.count - 1; i >= 0; i--) {
                indices.push(i)
            }
            root._batchHistoryClearQueue = indices
        }
        root._expandedGroups = ({})
        root._groupVersion++
    }

    // Compatibility with existing UI
    function discardNotification(id) {
        dismissActiveNotification(id)
    }

    function discardAllNotifications() {
        dismissAllActive()
        clearHistory()
    }

    function attemptInvokeAction(id, actionId) {
        const nd = _notifDataByInternalId[id]
        if (!nd) return
        nd.invokeAction(actionId)   // also dismisses
        cleanupNotification(id)
        popupDismissRequested(id)
    }

    // Public accessor for popup auto-dismiss timer; popups bind to this.
    function activeDuration(id) {
        const nd = _notifDataByInternalId[id]
        return nd ? nd.durationMs : 0
    }
}
