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
    property bool doNotDisturb: false

    // State
    property ListModel activeList: ListModel {}
    property ListModel historyList: ListModel {}

    property var activeNotifications: ({}) // notificationId -> { notification, watcher, timestamp, duration, paused, pauseTime }
    property var quickshellIdToInternalId: ({})
    property int _nextEntryId: 1

    // Persistent history
    readonly property string historyFile: StandardPaths.writableLocation(StandardPaths.ConfigLocation) + "/quickshell/notification-history.json"

    Component {
        id: notificationServerComponent
        NotificationServer {
            keepOnReload: false
            actionsSupported: true
            imageSupported: true

            onNotification: (notification) => {
                root.handleNotification(notification)
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

    Component.onCompleted: {
        notificationServerComponent.createObject(root)
        historyFileView.reload()
    }

    function handleNotification(notification) {
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

        addNewNotification(quickshellId, notification, data)
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
            "paused": false,
            "pauseTime": 0
        }

        notification.closed.connect(() => removeNotification(data.notificationId))

        activeList.insert(0, data)

        while (activeList.count > maxVisible) {
            const last = activeList.get(activeList.count - 1)
            dismissActiveNotification(last.notificationId)
        }
    }

    function updateExistingNotification(internalId, notification) {
        const index = findNotificationIndex(internalId)
        if (index < 0)
            return

        const normalized = normalizeNotification(notification)
        const contentId = getContentId(normalized.summary, normalized.body, normalized.appName)

        const existing = activeList.get(index)
        const existingProgress = existing ? (existing.progress ?? 1.0) : 1.0

        activeList.setProperty(index, "summary", normalized.summary)
        activeList.setProperty(index, "body", normalized.body)
        activeList.setProperty(index, "appName", normalized.appName)
        activeList.setProperty(index, "appIcon", normalized.appIcon)
        activeList.setProperty(index, "image", normalized.image)
        activeList.setProperty(index, "actions", normalized.actions)
        activeList.setProperty(index, "urgency", normalized.urgency)
        activeList.setProperty(index, "expireTimeout", normalized.expireTimeout)
        activeList.setProperty(index, "contentId", contentId)
        activeList.setProperty(index, "progress", existingProgress)

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
            activeList.remove(index)
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
        for (var i = 0; i < activeList.count; i++) {
            if (activeList.get(i).notificationId === internalId) {
                return i
            }
        }
        return -1
    }

    function findDuplicateNotification(contentId) {
        for (var i = 0; i < activeList.count; i++) {
            const existing = activeList.get(i)
            if (existing.contentId === contentId) {
                return existing.notificationId
            }
        }
        return null
    }

    function calculateDuration(data) {
        if (data.expireTimeout === 0)
            return -1
        if (data.expireTimeout > 0)
            return data.expireTimeout
        return defaultExpireTimeout
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

    // Active timeout loop
    Timer {
        interval: 250
        repeat: true
        running: activeList.count > 0
        onTriggered: root.updateAllTimeouts()
    }

    function updateAllTimeouts() {
        const now = Date.now()
        const expired = []

        for (var i = 0; i < activeList.count; i++) {
            const entry = activeList.get(i)
            const meta = activeNotifications[entry.notificationId]
            if (!meta)
                continue
            const duration = meta.duration
            if (duration < 0)
                continue
            if (meta.paused)
                continue
            const elapsed = now - meta.timestamp
            if (elapsed >= duration) {
                expired.push(entry.notificationId)
            } else {
                const progress = Math.max(1.0 - (elapsed / duration), 0.0)
                if (Math.abs(entry.progress - progress) > 0.005) {
                    activeList.setProperty(i, "progress", progress)
                }
            }
        }

        for (let i = 0; i < expired.length; i++) {
            dismissActiveNotification(expired[i])
        }
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
            for (const item of historyAdapter.notifications || []) {
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
        } catch (e) {
            console.warn("NotificationService: failed to load history", e)
        }
    }

    function addToHistory(data) {
        historyList.insert(0, data)
        while (historyList.count > maxHistory) {
            historyList.remove(historyList.count - 1)
        }
        saveHistory()
    }

    // Public API
    function dismissActiveNotification(id) {
        const meta = activeNotifications[id]
        if (meta && meta.notification && meta.notification.dismiss) {
            // dismiss() fires the closed signal which triggers removeNotification
            // via the connection set up in addNewNotification. Only call
            // removeNotification directly if dismiss is not available.
            meta.notification.dismiss()
        } else {
            removeNotification(id)
        }
    }

    function pauseTimeout(id) {
        const meta = activeNotifications[id]
        if (meta && !meta.paused) {
            meta.paused = true
            meta.pauseTime = Date.now()
        }
    }

    function resumeTimeout(id) {
        const meta = activeNotifications[id]
        if (meta && meta.paused) {
            meta.timestamp += Date.now() - meta.pauseTime
            meta.paused = false
        }
    }

    function dismissAllActive() {
        const ids = []
        for (var i = 0; i < activeList.count; i++) {
            ids.push(activeList.get(i).notificationId)
        }
        for (let i = 0; i < ids.length; i++) {
            dismissActiveNotification(ids[i])
        }
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
        historyList.clear()
        saveHistory()
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
