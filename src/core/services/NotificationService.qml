pragma Singleton

import QtQuick
import QtCore
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs.src.core.config

Singleton {
    id: root

    // Configuration
    property int maxVisible: AppConfig.notificationPopupMaxVisible
    property int maxHistory: 200
    property int defaultExpireTimeout: AppConfig.notificationPopupTimeout
    property bool doNotDisturb: AppConfig.stateData?.notifications?.doNotDisturb ?? false

    onDoNotDisturbChanged: AppConfig.updateState("notifications", { "doNotDisturb": doNotDisturb })

    // State
    property var activeList: []
    property ListModel historyList: ListModel {}

    property var activeNotifications: ({}) // notificationId -> { notification, watcher, timestamp, duration, hoverCount, pauseTime }
    property var quickshellIdToInternalId: ({})
    property int _nextEntryId: 1

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

    // Persistent history
    readonly property string historyFile: StandardPaths.writableLocation(StandardPaths.ConfigLocation) + "/quickshell/notification-history.json"

    Component {
        id: notificationServerComponent
        NotificationServer {
            keepOnReload: false
            actionsSupported: true
            imageSupported: true

            onNotification: (notification) => {
                root._ingestNotification(notification)
            }
        }
    }

    Component {
        id: notificationWatcherComponent
        Connections {
            property var targetNotification
            property string targetDataId
            target: targetNotification

            function onSummaryChanged() {
                root.updateNotificationFromObject(targetDataId)
            }
            function onBodyChanged() {
                root.updateNotificationFromObject(targetDataId)
            }
            function onAppNameChanged() {
                root.updateNotificationFromObject(targetDataId)
            }
            function onUrgencyChanged() {
                root.updateNotificationFromObject(targetDataId)
            }
            function onAppIconChanged() {
                root.updateNotificationFromObject(targetDataId)
            }
            function onImageChanged() {
                root.updateNotificationFromObject(targetDataId)
            }
            function onActionsChanged() {
                root.updateNotificationFromObject(targetDataId)
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
        notificationServerComponent.createObject(root)
        historyFileView.reload()
    }

    function _ingestNotification(notification) {
        const isCritical = notification.urgency === 2 // NotificationUrgency.Critical
        if (isCritical || root._rateBucketTokens > 0) {
            if (!isCritical) root._rateBucketTokens--
            _processNotification(notification)
        } else if (root._notificationQueue.length < root._maxQueueSize) {
            root._notificationQueue.push(notification)
            root._notificationQueue = root._notificationQueue // trigger change signal
        }
        // Drop if queue is full
    }

    function _processNotification(notification) {
        notification.tracked = true
        const data = createData(notification)
        addToHistory(data)

        if (doNotDisturb)
            return

        const quickshellId = notification.id
        const existingInternalId = quickshellIdToInternalId[quickshellId]
        if (existingInternalId && activeNotifications[existingInternalId]) {
            updateExistingNotification(existingInternalId, notification)
            return
        }

        const duplicateId = findDuplicateNotification(data.contentId)
        if (duplicateId) {
            removeNotification(duplicateId)
        }

        _gateShow(quickshellId, notification, data)
    }

    function _gateShow(quickshellId, notification, data) {
        if (root._gateOpen) {
            root._gateOpen = false
            gateTimer.restart()
            addNewNotification(quickshellId, notification, data)
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
        addNewNotification(item.quickshellId, item.notification, item.data)
    }

    // Keep for backward compatibility
    function handleNotification(notification) {
        _ingestNotification(notification)
    }

    function addNewNotification(quickshellId, notification, data) {
        quickshellIdToInternalId[quickshellId] = data.notificationId

        const watcher = notificationWatcherComponent.createObject(root, {
            "targetNotification": notification,
            "targetDataId": data.notificationId
        })

        activeNotifications[data.notificationId] = {
            "notification": notification,
            "watcher": watcher,
            "timestamp": data.timestamp,
            "duration": calculateDuration(data),
            "hoverCount": 0,
            "pauseTime": 0
        }

        notification.closed.connect(() => removeNotification(data.notificationId))

        activeList = [data].concat(activeList)

        while (activeList.length > maxVisible) {
            const last = activeList[activeList.length - 1]
            dismissActiveNotification(last.notificationId)
        }
    }

    function updateExistingNotification(internalId, notification) {
        const index = findNotificationIndex(internalId)
        if (index < 0)
            return

        const normalized = normalizeNotification(notification)
        const contentId = getContentId(normalized.summary, normalized.body, normalized.appName)
        const existingProgress = activeList[index].progress ?? 1.0

        let arr = activeList.slice()
        arr[index] = Object.assign({}, arr[index], {
            "summary": normalized.summary,
            "body": normalized.body,
            "appName": normalized.appName,
            "appIcon": normalized.appIcon,
            "image": normalized.image,
            "actions": normalized.actions,
            "urgency": normalized.urgency,
            "expireTimeout": normalized.expireTimeout,
            "contentId": contentId,
            "progress": existingProgress
        })
        activeList = arr

        const notifData = activeNotifications[internalId]
        if (notifData) {
            notifData.notification = notification
            notifData.duration = calculateDuration({
                expireTimeout: normalized.expireTimeout,
                urgency: normalized.urgency
            })
        }
    }

    function updateNotificationFromObject(internalId) {
        const notifData = activeNotifications[internalId]
        if (!notifData || !notifData.notification)
            return

        updateExistingNotification(internalId, notifData.notification)
    }

    function removeNotification(id) {
        const index = findNotificationIndex(id)
        if (index >= 0) {
            let arr = activeList.slice()
            arr.splice(index, 1)
            activeList = arr
        }
        cleanupNotification(id)
    }

    function cleanupNotification(id) {
        const notifData = activeNotifications[id]
        if (notifData) {
            notifData.watcher?.destroy()
            delete activeNotifications[id]
        }

        for (const qsId in quickshellIdToInternalId) {
            if (quickshellIdToInternalId[qsId] === id) {
                delete quickshellIdToInternalId[qsId]
                break
            }
        }
    }

    function findNotificationIndex(internalId) {
        for (var i = 0; i < activeList.length; i++) {
            if (activeList[i].notificationId === internalId) {
                return i
            }
        }
        return -1
    }

    function findDuplicateNotification(contentId) {
        for (var i = 0; i < activeList.length; i++) {
            if (activeList[i].contentId === contentId) {
                return activeList[i].notificationId
            }
        }
        return null
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
        const body = stripTags(notification.body || "")
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

    function stripTags(text) {
        return text.replace(/<[^>]*>?/gm, "")
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
            "timestamp": timestamp,
            "progress": 1.0
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

    // Adaptive timeout loop
    Timer {
        interval: activeList.length <= 1 ? 500 : 250
        repeat: true
        running: activeList.length > 0
        onTriggered: root.updateAllTimeouts()
    }

    function updateAllTimeouts() {
        const now = Date.now()
        const expired = []
        let arr = null

        for (var i = 0; i < activeList.length; i++) {
            const entry = activeList[i]
            const meta = activeNotifications[entry.notificationId]
            if (!meta)
                continue
            const duration = meta.duration
            if (duration < 0)
                continue
            if (meta.hoverCount > 0)
                continue
            const elapsed = now - meta.timestamp
            if (elapsed >= duration) {
                expired.push(entry.notificationId)
            } else {
                const progress = Math.max(1.0 - (elapsed / duration), 0.0)
                if (Math.abs(entry.progress - progress) > 0.005) {
                    if (!arr) arr = activeList.slice()
                    arr[i] = Object.assign({}, arr[i], {"progress": progress})
                }
            }
        }

        if (arr) activeList = arr

        for (let i = 0; i < expired.length; i++) {
            dismissActiveNotification(expired[i])
        }
    }

    // Hover count API
    function incrementHover(id) {
        const meta = activeNotifications[id]
        if (!meta) return
        if (meta.hoverCount === 0) {
            meta.pauseTime = Date.now()
        }
        meta.hoverCount++
    }

    function decrementHover(id) {
        const meta = activeNotifications[id]
        if (!meta || meta.hoverCount <= 0) return
        meta.hoverCount--
        if (meta.hoverCount === 0) {
            meta.timestamp += Date.now() - meta.pauseTime
        }
    }

    // Backward-compatible wrappers
    function pauseTimeout(id) {
        incrementHover(id)
    }

    function resumeTimeout(id) {
        decrementHover(id)
    }

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

    function loadHistory() {
        try {
            historyList.clear()
            const items = historyAdapter.notifications || []

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
        // Find the first item with the same appName — insert before it
        // so this new item is at the top of its group (newest first within group)
        // Also move the whole group to the top if it isn't already there
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
            // No existing items for this app — insert at top
            historyList.insert(0, data)
        } else if (groupStartIdx === 0) {
            // Group is already at the top — insert at position 0 (newest in group)
            historyList.insert(0, data)
        } else {
            // Group exists but not at top — move group to top
            // First insert the new item at position 0
            historyList.insert(0, data)
            // Move existing group items right after the new item
            // After insert, indices shifted by 1
            const count = groupEndIdx - groupStartIdx + 1
            for (let j = 0; j < count; j++) {
                historyList.move(groupStartIdx + 1 + j, 1 + j, 1)
            }
        }
    }

    // Grouping state for ListView sections
    function isGroupExpanded(appName) {
        return root._expandedGroups[appName] !== false
    }

    function toggleGroupExpanded(appName) {
        root._expandedGroups[appName] = !isGroupExpanded(appName)
        root._expandedGroups = root._expandedGroups // trigger change signal
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
    function dismissActiveNotification(id) {
        const meta = activeNotifications[id]
        if (meta && meta.notification && meta.notification.dismiss) {
            meta.notification.dismiss()
        }
        // Always remove immediately — don't depend on async closed signal
        removeNotification(id)
    }

    function dismissAllActive() {
        const ids = []
        for (var i = activeList.length - 1; i >= 0; i--) {
            ids.push(activeList[i].notificationId)
        }
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
            // Small enough to clear synchronously
            historyList.clear()
            saveHistory()
        } else {
            // Batch removal from end to start
            const indices = []
            for (var i = historyList.count - 1; i >= 0; i--) {
                indices.push(i)
            }
            root._batchHistoryClearQueue = indices
        }
        root._expandedGroups = ({})
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
        const meta = activeNotifications[id]
        const actions = meta?.notification?.actions
        if (!actions)
            return
        for (const action of actions) {
            if (action.identifier === actionId && action.invoke) {
                action.invoke()
                break
            }
        }
        dismissActiveNotification(id)
    }
}
