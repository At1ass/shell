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

    readonly property int maxHistory: AppConfig.notificationMaxHistory

    property ListModel historyList: ListModel {}

    // ── Unread tracking ──────────────────────────────────────────
    // Kept as a counter rather than recomputed from the model: the bar badge
    // binds to it, and a linear scan per add/remove/read would be O(n) on a
    // 200-row model for every notification.
    property int unreadCount: 0

    function _recountUnread() {
        let n = 0
        for (var i = 0; i < historyList.count; i++)
            if (historyList.get(i).unread) n++
        unreadCount = n
    }

    // Called when the notification centre opens — that is what "read" means
    // here: the user looked at the list.
    function markAllRead() {
        if (unreadCount === 0) return
        for (var i = 0; i < historyList.count; i++) {
            if (historyList.get(i).unread) historyList.setProperty(i, "unread", false)
        }
        unreadCount = 0
        save()
    }

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
    // Returns the actions of row i as a plain JS array. ListModel stores
    // nested arrays as sub-models, which delegate code cannot .filter().
    function actionsAt(i) {
        const nested = historyList.get(i)?.actions
        if (!nested || typeof nested.count !== "number") return []
        const out = []
        for (let j = 0; j < nested.count; j++) {
            const a = nested.get(j)
            out.push({ "identifier": a.identifier || "", "text": a.text || "" })
        }
        return out
    }

    // ── Group index ──────────────────────────────────────────────
    // appName → { count, icon }. Rebuilt once per mutation instead of scanned
    // per group: the centre's section delegate asks for count AND icon for
    // every group, and both used to walk the whole model, so rendering N groups
    // over n rows cost O(N·n) on every single add, remove or prune.
    property var _groupIndex: ({})

    function _rebuildGroupIndex() {
        const idx = ({})
        for (var i = 0; i < historyList.count; i++) {
            const item = historyList.get(i)
            const name = item.appName || ""
            const g = idx[name]
            if (g) g.count++
            else idx[name] = { "count": 1, "icon": item.appIcon || "" }
        }
        _groupIndex = idx
    }

    // Coalesce: a mass clear or a load touches the model many times in one turn.
    Timer {
        id: groupIndexTimer
        interval: 0
        repeat: false
        onTriggered: root._rebuildGroupIndex()
    }
    function _invalidateGroupIndex() { groupIndexTimer.restart() }

    function getGroupCount(appName) {
        return _groupIndex[appName]?.count ?? 0
    }
    function getGroupIcon(appName) {
        return _groupIndex[appName]?.icon ?? ""
    }

    // ── Public API ───────────────────────────────────────────────

    // Adds arriving before the initial file load would be wiped by
    // _load()'s clear(); buffer them and flush after.
    property bool _loadDone: false
    property var _pendingAdds: []

    function add(data) {
        if (!_loadDone) {
            _pendingAdds.push(data)
            return
        }
        if (AppConfig.notificationGroupByApp) {
            _sortedInsert(data)
        } else {
            historyList.insert(0, data)
        }
        if (data.unread) unreadCount++
        _invalidateGroupIndex()
        while (historyList.count > maxHistory) {
            if (historyList.get(historyList.count - 1).unread) unreadCount--
            historyList.remove(historyList.count - 1)
        }
        save()
    }

    // In-place update for a replaced notification (replaces_id). Without this
    // the centre kept showing whatever text the app sent FIRST — the only
    // add() call sits on the first-appearance path, and the server does not
    // re-emit notification() for a replacement.
    function update(id, fields) {
        for (var i = 0; i < historyList.count; i++) {
            if (historyList.get(i).notificationId !== id) continue
            for (const key in fields) {
                // `actions` is a nested list: ListModel cannot setProperty it,
                // so the row is rebuilt when actions actually change.
                if (key === "actions") continue
                historyList.setProperty(i, key, fields[key])
            }
            _invalidateGroupIndex()
            save()
            return true
        }
        return false
    }

    function remove(id) {
        for (var i = 0; i < historyList.count; i++) {
            if (historyList.get(i).notificationId === id) {
                if (historyList.get(i).unread && unreadCount > 0) unreadCount--
                historyList.remove(i)
                _invalidateGroupIndex()
                save()
                return true
            }
        }
        return false
    }

    function clear() {
        unreadCount = 0
        _invalidateGroupIndex()
        if (historyList.count <= 16) {
            historyList.clear()
            save()
        } else {
            // Queue IDs, not indices: an add() during the multi-tick drain
            // shifts rows, and captured indices would delete the fresh
            // notification while leaving a stale row behind.
            const ids = []
            for (var i = 0; i < historyList.count; i++)
                ids.push(historyList.get(i).notificationId)
            _batchClearQueue = ids
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
        onLoadFailed: error => {
            if (error === 2) writeAdapter()   // FileNotFound: create it
            // Buffered adds must flush even without a readable file.
            root._loadDone = true
            const pending = root._pendingAdds
            root._pendingAdds = []
            for (const d of pending) root.add(d)
        }

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
                    "actions": actionsAt(i),   // nested sub-model serializes to null
                    "urgency": e.urgency,
                    "expireTimeout": e.expireTimeout,
                    "timestamp": e.timestamp,
                    "closeReason": e.closeReason ?? -1,
                    "count": e.count ?? 1,
                    "unread": e.unread ?? false
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
        _recountUnread()
        _rebuildGroupIndex()
        _loadDone = true
        const pending = _pendingAdds
        _pendingAdds = []
        for (const d of pending) add(d)
    }

    function _normaliseEntry(item) {
        const id = item.notificationId || item.id || ""
        return {
            "notificationId": id,
            "id": id,
            // notifId only matters while the notification is still live, which
            // it never is after a reload — 0 marks "actions no longer usable".
            "notifId": item.notifId ?? 0,
            "count": item.count ?? 1,
            "unread": item.unread ?? false,
            "summary": item.summary || "",
            "body": item.body || "",
            "appName": item.appName || "",
            "appIcon": item.appIcon || "",
            // image://qsimage/ handles live only as long as the tracked
            // notification — persisting one stores a dangling pointer that
            // spams the image provider on every scroll. Keep stable URLs only.
            "image": (item.image || "").startsWith("image://qsimage/") ? "" : (item.image || ""),
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
                if (historyList.get(i).unread && unreadCount > 0) unreadCount--
                historyList.remove(i)
                removed = true
            }
        }
        if (removed) { _invalidateGroupIndex(); save() }
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
            // Drain through a FRESH array. Shifting in place and assigning the
            // same reference back does not emit the change signal, so `running`
            // above never re-evaluated: the timer kept firing at 125 Hz after
            // the queue emptied, and its save() restarted the 200 ms debounce
            // every 8 ms — history silently stopped persisting for the session.
            const queue = root._batchClearQueue.slice()
            const count = Math.min(8, queue.length)
            for (let i = 0; i < count; i++) {
                const id = queue.shift()
                for (var r = 0; r < historyList.count; r++) {
                    if (historyList.get(r).notificationId === id) {
                        historyList.remove(r)
                        break
                    }
                }
            }
            root._batchClearQueue = queue
            _invalidateGroupIndex()
            if (queue.length === 0) save()
        }
    }
}
