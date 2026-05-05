pragma Singleton

import QtQuick
import QtCore
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs.src.core.config

// Notification history: ListModel + JSON persistence + grouping.
//
// Owns a single ListModel. All UI consumers (NotificationCenter) bind to
// `historyList` and call mutating methods through this singleton. Service
// adds entries via `add(data)`; close-reason tagging is optional via
// `tagCloseReason(internalId, reason)`.
//
// Persistence: JsonAdapter writes ${configHome}/quickshell/notification-
// history.json on every mutation (debounced 200ms). On startup the file
// is reloaded; entries older than `notificationHistoryTTLDays` are
// filtered out at load time, and an hourly timer prunes ongoing.

Singleton {
    id: root

    property int maxHistory: 200

    property ListModel historyList: ListModel {}

    readonly property string historyFile:
        StandardPaths.writableLocation(StandardPaths.ConfigLocation)
        + "/quickshell/notification-history.json"

    // ── Group expansion ──────────────────────────────────────────
    // Map of appName -> bool. Reading _groupVersion creates a binding
    // dependency, so callers re-evaluate isGroupExpanded() when the
    // map mutates via toggleGroupExpanded().
    property var _expandedGroups: ({})
    property int _groupVersion: 0

    function isGroupExpanded(appName) {
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

    // ── Public API ───────────────────────────────────────────────

    function add(data) {
        if (AppConfig.notificationGroupByApp) {
            _sortedInsert(data)
        } else {
            historyList.insert(0, data)
        }
        while (historyList.count > maxHistory) {
            historyList.remove(historyList.count - 1)
        }
        save()
    }

    function remove(id) {
        for (var i = 0; i < historyList.count; i++) {
            if (historyList.get(i).notificationId === id) {
                historyList.remove(i)
                save()
                return true
            }
        }
        return false
    }

    function clear() {
        if (historyList.count <= 16) {
            historyList.clear()
            save()
        } else {
            const indices = []
            for (var i = historyList.count - 1; i >= 0; i--) indices.push(i)
            _batchClearQueue = indices
        }
        root._expandedGroups = ({})
        root._groupVersion++
    }

    // Optional: tag a recent history entry with the close reason from
    // the underlying notification. No-op if entry not found (already pruned).
    function tagCloseReason(id, reason) {
        for (var i = 0; i < historyList.count; i++) {
            if (historyList.get(i).notificationId === id) {
                historyList.setProperty(i, "closeReason", reason)
                save()
                return
            }
        }
    }

    // ── Persistence ──────────────────────────────────────────────

    FileView {
        id: historyFileView
        path: historyFile
        printErrors: false
        onLoaded: _load()
        onLoadFailed: error => { if (error === 2) writeAdapter() }

        JsonAdapter {
            id: historyAdapter
            property var notifications: []
        }
    }

    Component.onCompleted: historyFileView.reload()

    Timer {
        id: saveTimer
        interval: 200
        repeat: false
        onTriggered: _persist()
    }

    function save() { saveTimer.restart() }

    function _persist() {
        try {
            const items = []
            for (var i = 0; i < historyList.count; i++) {
                const e = historyList.get(i)
                items.push({
                    "notificationId": e.notificationId,
                    "summary": e.summary,
                    "body": e.body,
                    "appName": e.appName,
                    "appIcon": e.appIcon,
                    "image": e.image,
                    "actions": e.actions || [],
                    "urgency": e.urgency,
                    "expireTimeout": e.expireTimeout,
                    "timestamp": e.timestamp,
                    "closeReason": e.closeReason ?? -1
                })
            }
            historyAdapter.notifications = items
            historyFileView.writeAdapter()
        } catch (err) {
            console.warn("NotificationHistory: persist failed:", err)
        }
    }

    function _load() {
        try {
            historyList.clear()
            const ttl = AppConfig.notificationHistoryTTLDays
            const cutoff = ttl > 0 ? Date.now() - (ttl * 24 * 60 * 60 * 1000) : 0
            const all = historyAdapter.notifications || []
            const items = cutoff > 0 ? all.filter(i => (i.timestamp || 0) >= cutoff) : all

            if (AppConfig.notificationGroupByApp) {
                const groups = {}
                const order = []
                for (const item of items) {
                    const name = item.appName || "Unknown"
                    if (!groups[name]) { groups[name] = []; order.push(name) }
                    groups[name].push(item)
                }
                order.sort((a, b) => {
                    const aMax = Math.max(...groups[a].map(i => i.timestamp || 0))
                    const bMax = Math.max(...groups[b].map(i => i.timestamp || 0))
                    return bMax - aMax
                })
                for (const name of order) {
                    groups[name].sort((a, b) => (b.timestamp || 0) - (a.timestamp || 0))
                    for (const item of groups[name]) historyList.append(_normaliseEntry(item))
                }
            } else {
                for (const item of items) historyList.append(_normaliseEntry(item))
            }
        } catch (err) {
            console.warn("NotificationHistory: load failed:", err)
        }
    }

    function _normaliseEntry(item) {
        const id = item.notificationId || item.id || ""
        return {
            "notificationId": id,
            "id": id,
            "summary": item.summary || "",
            "body": item.body || "",
            "appName": item.appName || "",
            "appIcon": item.appIcon || "",
            "image": item.image || "",
            "actions": item.actions || [],
            "urgency": (item.urgency < 0 || item.urgency > 2) ? NotificationUrgency.Normal : item.urgency,
            "expireTimeout": item.expireTimeout,
            "timestamp": item.timestamp || 0,
            "closeReason": item.closeReason ?? -1
        }
    }

    // Insert keeping the same-app group contiguous at the top.
    function _sortedInsert(data) {
        const appName = data.appName || "Unknown"
        let groupStart = -1
        let groupEnd = -1
        for (var i = 0; i < historyList.count; i++) {
            const item = historyList.get(i)
            if ((item.appName || "Unknown") === appName) {
                if (groupStart < 0) groupStart = i
                groupEnd = i
            } else if (groupStart >= 0) {
                break
            }
        }
        if (groupStart < 0 || groupStart === 0) {
            historyList.insert(0, data)
            return
        }
        historyList.insert(0, data)
        const count = groupEnd - groupStart + 1
        for (let j = 0; j < count; j++) {
            historyList.move(groupStart + 1 + j, 1 + j, 1)
        }
    }

    // ── TTL prune ────────────────────────────────────────────────

    Timer {
        interval: 60 * 60 * 1000
        repeat: true
        running: true
        onTriggered: root._prune()
    }

    function _prune() {
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
        if (removed) save()
    }

    // ── Batched mass-clear ──────────────────────────────────────
    // For large history (>16 entries), spread removal across ticks so
    // the ListView doesn't stutter on a single mass-mutation.
    property var _batchClearQueue: []

    Timer {
        interval: 8
        repeat: true
        running: root._batchClearQueue.length > 0
        onTriggered: {
            const count = Math.min(8, root._batchClearQueue.length)
            for (let i = 0; i < count; i++) {
                const idx = root._batchClearQueue.shift()
                if (idx < historyList.count) historyList.remove(idx)
            }
            root._batchClearQueue = root._batchClearQueue
            if (root._batchClearQueue.length === 0) save()
        }
    }
}
