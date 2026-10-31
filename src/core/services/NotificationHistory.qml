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

    readonly property int maxHistory: Math.max(1, AppConfig.notificationMaxHistory)

    property ListModel historyList: ListModel {}
    property var _undoEntries: []
    property real _undoDeadline: 0
    property bool _restoreRequested: false
    property var _restoreQueue: []
    readonly property bool clearing: _batchClearQueue.length > 0
    readonly property bool restoring: _restoreRequested
    readonly property bool canUndoClear: _undoEntries.length > 0 && _undoDeadline > 0 && !restoring
    readonly property int undoCount: _undoEntries.length
    onMaxHistoryChanged: if (_loadDone) _trimHistory()

    function _trimHistory() {
        while (historyList.count > maxHistory) {
            const entry = historyList.get(historyList.count - 1)
            if (entry.unread && unreadCount > 0) unreadCount--
            _forgetEntryState(entry.notificationId)
            historyList.remove(historyList.count - 1)
        }
        _invalidateGroupIndex()
        save()
    }
    function refreshUndo() {
        if (restoring || !_undoEntries.length) return
        const remaining = _undoDeadline - Date.now()
        if (remaining <= 0) commitClear()
        else { undoTimer.interval = remaining; undoTimer.restart() }
    }
    function commitClear() {
        undoTimer.stop()
        _undoEntries = []
        _undoDeadline = 0
        _restoreRequested = false
        _restoreQueue = []
        save()
    }
    function clearUndoable() {
        if (clearing || restoring || historyList.count === 0) return false
        commitClear()
        const entries = []
        for (let i = 0; i < historyList.count; i++) entries.push(_entryAt(i))
        _undoEntries = entries
        _undoDeadline = Date.now() + AppConfig.notificationClearUndoTimeout
        refreshUndo()
        _startClear()
        return true
    }
    function undoClear() {
        refreshUndo()
        if (!canUndoClear) return false
        undoTimer.stop()
        _restoreRequested = true
        if (!clearing) _startRestore()
        save()
        return true
    }
    function _startRestore() {
        const present = ({})
        for (let i = 0; i < historyList.count; i++) present[historyList.get(i).notificationId] = true
        _restoreQueue = _undoEntries.filter(entry => !present[entry.notificationId])
        if (!_restoreQueue.length) commitClear()
    }
    function _updateUndo(id, fields) {
        for (const entry of _undoEntries) {
            if (entry.notificationId !== id) continue
            Object.assign(entry, fields)
            if (fields.notifId === 0 && fields.closeReason !== undefined && (entry.image || "").startsWith("image://qsimage/")) entry.image = ""
            save()
            return true
        }
        return false
    }
    function _excludeUndo(id, appName) {
        const keep = entry => id ? entry.notificationId !== id : entry.appName !== appName
        _undoEntries = _undoEntries.filter(keep)
        _restoreQueue = _restoreQueue.filter(keep)
        if (!_undoEntries.length || (restoring && !clearing && !_restoreQueue.length)) commitClear()
        else save()
    }
    Timer { id: undoTimer; onTriggered: root.commitClear() }
    Timer {
        interval: 8
        repeat: true
        running: root.restoring && !root.clearing && root._restoreQueue.length > 0
        onTriggered: {
            const queue = root._restoreQueue.slice()
            const cutoff = AppConfig.notificationHistoryTTLDays > 0
                ? Date.now() - AppConfig.notificationHistoryTTLDays * 86400000 : 0
            for (let i = 0; i < 8 && queue.length; i++) {
                const entry = queue.shift()
                // Current arrivals have priority over restored older records.
                if (root.historyList.count >= root.maxHistory || entry.timestamp < cutoff) continue
                let position = root.historyList.count
                if (AppConfig.notificationGroupByApp) {
                    for (let r = 0; r < root.historyList.count; r++) {
                        if (root.historyList.get(r).appName === entry.appName) {
                            position = r + 1
                            while (position < root.historyList.count && root.historyList.get(position).appName === entry.appName) position++
                            break
                        }
                    }
                }
                root.historyList.insert(position, entry)
                if (entry.unread) root.unreadCount++
            }
            root._restoreQueue = queue
            root._invalidateGroupIndex()
            if (!queue.length) root.commitClear()
            else root.save()
        }
    }

    // ── Unread tracking ──────────────────────────────────────────
    // Kept as a counter rather than recomputed from the model: the bar badge
    // binds to it, and a linear scan per add/remove/read would be O(n) on a
    // 200-row model for every notification.
    property int unreadCount: 0

    function _recountUnread() {
        let n = 0
        for (let i = 0; i < historyList.count; i++)
            if (historyList.get(i).unread) n++
        unreadCount = n
    }

    // Called when the notification centre closes, including a retained panel.
    function markAllRead() {
        let pendingChanged = false
        for (const entry of _undoEntries) {
            if (entry.unread) { entry.unread = false; pendingChanged = true }
        }
        if (pendingChanged) save()
        if (unreadCount === 0) return
        for (let i = 0; i < historyList.count; i++) {
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
    // Keep view state by ID, outside delegates that ListView destroys.
    // Only collapsed entries need storage; the default is expanded.
    property var _collapsedEntries: ({})

    function isEntryExpanded(id) { return root._collapsedEntries[id] !== true }

    function setEntryExpanded(id, expanded) {
        if (!id || isEntryExpanded(id) === expanded) return
        const collapsed = Object.assign({}, root._collapsedEntries)
        if (expanded) delete collapsed[id]
        else collapsed[id] = true
        root._collapsedEntries = collapsed
    }

    function _forgetEntryState(id) {
        if (root._collapsedEntries[id] === undefined) return
        const collapsed = Object.assign({}, root._collapsedEntries)
        delete collapsed[id]
        root._collapsedEntries = collapsed
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
        for (let i = 0; i < historyList.count; i++) {
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
    property bool _historyReceived: false
    Connections {
        target: AppConfig
        function onReadyChanged() { if (AppConfig.ready && !root._loadDone) root._load() }
    }
    property var _pendingAdds: []

    function add(data) {
        if (!_loadDone) {
            const next = _pendingAdds.concat([data])
            _pendingAdds = next.slice(-(AppConfig.ready ? maxHistory : 2000))
            return
        }
        if (AppConfig.notificationGroupByApp) {
            _sortedInsert(data)
        } else {
            historyList.insert(0, data)
        }
        if (data.unread) unreadCount++
        _invalidateGroupIndex()
        _trimHistory()
        save()
    }

    // In-place update for a replaced notification (replaces_id). Without this
    // the centre kept showing whatever text the app sent FIRST — the only
    // add() call sits on the first-appearance path, and the server does not
    // re-emit notification() for a replacement.
    function update(id, fields) {
        const pendingUpdated = _updateUndo(id, fields)
        for (let i = 0; i < historyList.count; i++) {
            if (historyList.get(i).notificationId !== id) continue
            for (const key in fields) {
                // Nested actions need ListModel.set(), which updates the
                // sub-model while preserving the history row's stable ID.
                if (key === "actions") {
                    historyList.set(i, { "actions": fields.actions })
                    continue
                }
                historyList.setProperty(i, key, fields[key])
            }
            if (fields.notifId === 0 && fields.closeReason !== undefined && (historyList.get(i).image || "").startsWith("image://qsimage/")) historyList.setProperty(i,"image","")
            _invalidateGroupIndex()
            save()
            return true
        }
        return pendingUpdated
    }

    function removeUndoable(id) {
        if (clearing || restoring) return false
        for (let i=0;i<historyList.count;i++) {
            if (historyList.get(i).notificationId !== id) continue
            const entry = _entryAt(i)
            commitClear()
            if (!remove(id)) return false
            _undoEntries = [entry]
            _undoDeadline = Date.now() + AppConfig.notificationClearUndoTimeout
            refreshUndo()
            save()
            return true
        }
        return false
    }

    function remove(id) {
        _excludeUndo(id, "")
        for (let i = 0; i < historyList.count; i++) {
            if (historyList.get(i).notificationId === id) {
                if (historyList.get(i).unread && unreadCount > 0) unreadCount--
                _forgetEntryState(id)
                historyList.remove(i)
                _invalidateGroupIndex()
                save()
                return true
            }
        }
        return false
    }

    function removeGroup(appName) {
        _excludeUndo("", appName)
        for (let i = historyList.count - 1; i >= 0; i--) {
            const entry = historyList.get(i)
            if (entry.appName !== appName) continue
            if (entry.unread && unreadCount > 0) unreadCount--
            _forgetEntryState(entry.notificationId)
            historyList.remove(i)
        }
        _invalidateGroupIndex()
        save()
    }

    function clear() {
        commitClear()
        _startClear()
    }
    function _startClear() {
        _invalidateGroupIndex()
        if (historyList.count <= 16) {
            _batchClearQueue = []
            unreadCount = 0
            historyList.clear()
            save()
        } else {
            // Queue IDs, not indices: an add() during the multi-tick drain
            // shifts rows, and captured indices would delete the fresh
            // notification while leaving a stale row behind.
            const ids = []
            for (let i = 0; i < historyList.count; i++)
                ids.push(historyList.get(i).notificationId)
            _batchClearQueue = ids
        }
        root._collapsedEntries = ({})
        root._expandedGroups = ({})
        root._groupVersion++
    }

    // Optional: tag a recent history entry with the close reason from
    // the underlying notification. No-op if entry not found (already pruned).
    function tagCloseReason(id, reason) {
        update(id, {closeReason: reason, notifId: 0})
    }

    function _entryAt(index) {
        const e = historyList.get(index)
        return {notificationId:e.notificationId,id:e.notificationId,notifId:e.notifId ?? 0,
            summary:e.summary,body:e.body,appName:e.appName,appIcon:e.appIcon,image:e.image,
            actions:actionsAt(index),urgency:e.urgency,expireTimeout:e.expireTimeout ?? 0,
            timestamp:e.timestamp,closeReason:e.closeReason ?? -1,count:e.count ?? 1,unread:e.unread ?? false}
    }
    function _persistentEntry(entry) {
        const stored = Object.assign({}, entry, {notifId:0})
        if ((stored.image || "").startsWith("image://qsimage/")) stored.image = ""
        return stored
    }

    // ── Persistence ──────────────────────────────────────────────

    FileView {
        id: historyFileView
        path: historyFile
        printErrors: false
        onLoaded: { root._historyReceived = true; if (!root._loadDone) root._load() }
        onLoadFailed: error => {
            if (error === 2) writeAdapter()   // FileNotFound: create it
            // Use the same readiness gate when the file is absent/unreadable.
            root._historyReceived = true
            root._load()
        }

        // Quickshell's qmltypes omit the FileViewAdapter base type.
        // Suppress only that metadata warning for this adapter declaration.
        // qmllint disable unresolved-type
        JsonAdapter {
            id: historyAdapter
            property var notifications: []
            property var undoEntries: []
            property real undoDeadline: 0
            property bool restoreRequested: false
            property var clearingIds: []
        }
        // qmllint enable unresolved-type
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
            for (let i = 0; i < historyList.count; i++) items.push(_persistentEntry(_entryAt(i)))
            historyAdapter.undoEntries = _undoEntries.map(entry => _persistentEntry(entry))
            historyAdapter.undoDeadline = _undoDeadline
            historyAdapter.restoreRequested = _restoreRequested
            historyAdapter.clearingIds = _batchClearQueue.slice()
            historyAdapter.notifications = items
            historyFileView.writeAdapter()
        } catch (err) {
            console.warn("NotificationHistory: persist failed:", err)
        }
    }

    function _load() {
        if (!AppConfig.ready || !_historyReceived) return
        try {
            historyList.clear()
            root._collapsedEntries = ({})
            const ttl = AppConfig.notificationHistoryTTLDays
            const cutoff = ttl > 0 ? Date.now() - (ttl * 24 * 60 * 60 * 1000) : 0
            const pending = Array.from(historyAdapter.undoEntries ?? [])
            const hidden = ({})
            for (const entry of pending) hidden[entry.notificationId] = true
            for (const id of Array.from(historyAdapter.clearingIds ?? [])) hidden[id] = true
            _undoDeadline = Math.min(historyAdapter.undoDeadline || 0, Date.now() + AppConfig.notificationClearUndoTimeout)
            _restoreRequested = historyAdapter.restoreRequested && pending.length > 0
            _undoEntries = (_restoreRequested || _undoDeadline > Date.now())
                ? pending.filter(entry => !cutoff || entry.timestamp >= cutoff).slice(0,maxHistory).map(entry => _normaliseEntry(entry)) : []
            const all = (historyAdapter.notifications || []).filter(entry => !hidden[entry.notificationId])
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
        _trimHistory()
        if (_restoreRequested) _startRestore()
        else refreshUndo()
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
            "expireTimeout": item.expireTimeout ?? 0,
            "timestamp": item.timestamp || 0,
            "closeReason": item.closeReason ?? -1
        }
    }

    // Insert keeping the same-app group contiguous at the top.
    function _sortedInsert(data) {
        const appName = data.appName || "Unknown"
        let groupStart = -1
        let groupEnd = -1
        for (let i = 0; i < historyList.count; i++) {
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
                _forgetEntryState(historyList.get(i).notificationId)
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
                for (let r = 0; r < historyList.count; r++) {
                    if (historyList.get(r).notificationId === id) {
                        if (historyList.get(r).unread && root.unreadCount > 0) root.unreadCount--
                        root._forgetEntryState(id)
                        historyList.remove(r)
                        break
                    }
                }
            }
            root._batchClearQueue = queue
            _invalidateGroupIndex()
            if (queue.length === 0) {
                if (root._restoreRequested) root._startRestore()
                save()
            }
        }
    }
}
