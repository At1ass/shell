pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs.src.core.config

// NotificationService — the single owner of a notification's lifecycle.
//
// Everything that can close a notification goes through here. Presentation
// layers (NotificationPopupManager, NotificationCenter) render and report user
// intent; they never call dismiss/expire/tracked themselves. That rule is the
// fix for a whole class of bugs where the popup vanished but the notification
// stayed alive on the server — most notably the maxVisible cap, which used to
// live in the popup manager and simply destroyed windows.
//
// Identity: LIVE notifications are addressed by `notification.id` — a stable
// quint32 the server declares CONSTANT. The internal entry id (contentId:ts:n)
// exists only as the history row key, because history rows outlive the
// notifications they came from and have nothing else to be keyed on. A prior
// version carried the internal id for live popups too, which needed three
// cross-referenced maps kept in sync by hand from three different files.
//
// ── Two Quickshell traps worth knowing before editing ──────────────────────
//
// 1. `notification.tracked = false` is NOT "release our reference". Upstream it
//    is close(Dismissed) → NotificationClosed(id, 2) on the bus, and reason 2
//    means "dismissed by the user" per the freedesktop spec. Use expire()
//    (reason 1) whenever the user never actually saw the notification.
//
// 2. `mCloseReason` is initialised to Dismissed and isTracked() is
//    `mCloseReason == 0`, so a fresh notification is NOT tracked by default:
//    Notify() deletes it right after the signal unless the handler sets
//    tracked = true synchronously. The line in _ingest that looks redundant is
//    load-bearing.

Singleton {
    id: root

    // ── Outgoing signals (consumed by NotificationPopupManager) ────
    // All three key on notification.id.
    signal popupRequested(int notifId, var data)
    // `newNotifId` differs from `notifId` only when a duplicate merged into an
    // existing popup and re-keyed it onto the newer notification.
    signal popupUpdated(int notifId, int newNotifId, var data)
    signal popupDismissRequested(int notifId)

    // ── Live state ────────────────────────────────────────────────
    // notifId → { data, notifData }. One map, one owner.
    property var _live: ({})
    // notifId in display order, oldest first — drives the maxVisible cap.
    property var _order: []
    // notifId → history entry id. Set for EVERY admitted notification, even
    // when no popup is shown, so an in-place replacement under DND still
    // reaches the history row.
    property var _entryIdByNotifId: ({})

    property int _nextEntryId: 1

    // Invalid config must not make the eviction loop infinite.
    readonly property int maxVisible: Math.max(1, AppConfig.notificationPopupMaxVisible)

    // ── Server + per-notification wrappers ────────────────────────
    NotificationServer {
        id: notifServer
        keepOnReload: false
        actionsSupported: true
        imageSupported: true
        bodyMarkupSupported: true

        onNotification: (notification) => root._ingest(notification)
    }

    Instantiator {
        id: notifDataInstantiator
        model: notifServer.trackedNotifications
        delegate: NotifData {
            id: notifData
            required property Notification modelData
            notification: modelData

            // Property changes are how an in-place replacement (replaces_id)
            // reaches us: the server does NOT re-emit notification() for those,
            // it only mutates the object. Connections is a non-visual QObject
            // and QtObject has no default children list, hence the property.
            readonly property Connections _serviceWatch: Connections {
                target: notifData.modelData
                function onSummaryChanged()  { root._onReplaced(notifData.modelData) }
                function onBodyChanged()     { root._onReplaced(notifData.modelData) }
                function onAppNameChanged()  { root._onReplaced(notifData.modelData) }
                function onUrgencyChanged()  { root._onReplaced(notifData.modelData) }
                function onAppIconChanged()  { root._onReplaced(notifData.modelData) }
                function onImageChanged()    { root._onReplaced(notifData.modelData) }
                function onActionsChanged()  { root._onReplaced(notifData.modelData) }
            }
            onClosed: (reason) => root._onClosed(notifData.modelData, reason)
        }

        onObjectAdded: (index, object) => {
            const nd = object as NotifData
            if (nd?.notification) root._pending[nd.notification.id] = nd
        }
        onObjectRemoved: (index, object) => {
            const nd = object as NotifData
            if (nd?.notification) delete root._pending[nd.notification.id]
        }
    }

    // NotifData delegates land here first; _admit moves the ones it keeps into
    // _live. Separate from _live because the Instantiator's lifetime is driven
    // by the server, not by whether we chose to show anything.
    property var _pending: ({})

    // ── Rate-limiter wiring ───────────────────────────────────────
    // The limiter is pure policy: it never touches a notification's lifecycle,
    // it only reports verdicts. Closing is this file's job, always.
    Connections {
        target: NotificationRateLimiter

        function onIngressAccepted(notification) {
            // Notify() emits notification() BEFORE inserting into
            // trackedNotifications, so the Instantiator has not produced the
            // NotifData yet. Deferring one turn lets the model settle.
            Qt.callLater(() => root._admit(notification))
        }
        function onIngressDropped(notification) {
            // Queue full. The user never saw it — expire, do not "dismiss".
            root._expireNotification(notification)
        }
        function onPopupReady(notification, data) {
            root._show(notification, data)
        }
        function onPopupDropped(notification) {
            root._expireNotification(notification)
        }
    }

    // ── Ingest → admit → show ─────────────────────────────────────

    function _ingest(notification) {
        // Load-bearing: see trap 2 in the header comment.
        notification.tracked = true
        NotificationRateLimiter.ingest(notification)
    }

    function _admit(notification) {
        if (!_alive(notification)) return

        const nd = _pending[notification.id]
        if (!nd) {
            console.warn("NotificationService: NotifData missing for", notification.id)
            return
        }

        const data = createData(notification)
        _entryIdByNotifId[notification.id] = data.id

        // `transient` means "skip any kind of persistence function like a
        // notification area" — a progress bar or volume OSD must not silt up
        // the history. Per-app noHistory is the user-side equivalent.
        const appKey = _appKey(notification)
        if (!notification.transient && !_isFiltered(appKey, AppConfig.notificationNoHistoryApps))
            NotificationHistory.add(data)

        if (!AppConfig.moduleEnabled("notifications")) {
            _expireNotification(notification)
            return
        }

        // Critical always gets through. The limiter already treats it as
        // special (it bypasses the token bucket); DND used to not, which left
        // the subsystem disagreeing with itself about what "critical" means.
        const isCritical = notification.urgency === NotificationUrgency.Critical
        if (NotificationDND.active && !isCritical) {
            _expireNotification(notification)
            return
        }

        if (_isFiltered(appKey, AppConfig.notificationNoPopupApps)) {
            _expireNotification(notification)
            return
        }

        // Same content already on screen → merge into that popup as a count
        // instead of racing two identical cards. The older notification is
        // expired and its popup re-keys onto this one, so the visible card
        // always carries the newest content and actions.
        const dupId = _findDuplicate(data.contentId, notification.id)
        if (dupId >= 0) {
            const prev = _live[dupId]
            const merged = Object.assign({}, data, { "count": (prev?.data?.count ?? 1) + 1 })
            _live[notification.id] = { "data": merged, "notifData": nd }
            _replaceInOrder(dupId, notification.id)
            delete _live[dupId]
            popupUpdated(dupId, notification.id, merged)
            if (prev?.notifData?.notification) _expireNotification(prev.notifData.notification)
            return
        }

        NotificationRateLimiter.popupShow(notification, data)
    }

    function _show(notification, data) {
        if (!_alive(notification)) return
        const nd = _pending[notification.id]
        if (!nd) return

        // The cap lives here, with the lifecycle. When the popup manager owned
        // it, eviction destroyed the window and left the notification tracked
        // on the server forever — one leaked Notification (plus its NotifData
        // and any image-data pixmap) per eviction.
        while (_order.length >= maxVisible) {
            const oldest = _order[0]
            const victim = _live[oldest]
            if (victim?.notifData?.notification) {
                _expireNotification(victim.notifData.notification)
            } else {
                _forget(oldest)
                popupDismissRequested(oldest)
            }
            // _expireNotification closes synchronously via onClosed → _forget,
            // but guard against a wrapper that refuses to die.
            if (_order.length > 0 && _order[0] === oldest) {
                _forget(oldest)
                popupDismissRequested(oldest)
            }
        }

        _live[notification.id] = { "data": data, "notifData": nd }
        _order = _order.concat([notification.id])
        popupRequested(notification.id, data)
    }

    // ── Replacement (replaces_id) ─────────────────────────────────

    function _onReplaced(notification) {
        if (!_alive(notification)) return
        const entryId = _entryIdByNotifId[notification.id]
        if (entryId === undefined) return

        const normalized = normalizeNotification(notification)
        const contentId = getContentId(normalized.summary, normalized.body, normalized.appName)

        // History first, and unconditionally: an app updating a notification in
        // place (download progress, track change, unread counter) previously
        // left the ORIGINAL text in the centre forever, because the only
        // History.add() call sits on the first-appearance path. Under DND it was
        // worse — the popup path exits early, so nothing was updated at all.
        if (!notification.transient)
            NotificationHistory.update(entryId, normalized)

        const entry = _live[notification.id]
        if (!entry) return

        const merged = Object.assign({}, entry.data, normalized, { "contentId": contentId })
        entry.data = merged
        popupUpdated(notification.id, notification.id, merged)
    }

    // ── Close paths ───────────────────────────────────────────────
    // Everything funnels through the notification's own closed() signal, so
    // there is exactly one teardown site no matter who initiated the close.

    function _onClosed(notification, reason) {
        const id = notification.id
        const entryId = _entryIdByNotifId[id]
        if (entryId !== undefined) {
            NotificationHistory.tagCloseReason(entryId, reason)
            delete _entryIdByNotifId[id]
        }
        if (_live[id] !== undefined) {
            _forget(id)
            popupDismissRequested(id)
        }
    }

    function _forget(notifId) {
        delete _live[notifId]
        _order = _order.filter(x => x !== notifId)
    }

    function _replaceInOrder(oldId, newId) {
        _order = _order.map(x => (x === oldId ? newId : x))
    }

    // expire() = reason 1 (Expired). Correct for every path where the shell
    // dropped the notification on its own: DND, filters, module off, queue
    // overflow, maxVisible eviction. `tracked = false` would tell the client
    // the USER dismissed it (reason 2), which is a different fact.
    function _expireNotification(notification) {
        if (!_alive(notification)) return
        notification.expire()
    }

    function _alive(n) {
        try { return n !== null && n !== undefined && n.id !== undefined } catch (e) { return false }
    }

    function _findDuplicate(contentId, exceptId) {
        for (const key in _live) {
            const id = Number(key)
            if (id === exceptId) continue
            if (_live[key]?.data?.contentId === contentId) return id
        }
        return -1
    }

    function _appKey(notification) {
        return ((notification.appName || notification.desktopEntry || "") + "").toLowerCase().trim()
    }

    function _isFiltered(appKey, list) {
        if (!appKey || !list || list.length === 0) return false
        return list.indexOf(appKey) !== -1
    }

    // ── Public API (user intent, from the UI) ─────────────────────
    //
    // dismiss  → the user acted (X button, swipe): reason 2, which is true.
    // expire   → the popup's own countdown ran out: reason 1.
    // Both just close; teardown happens in _onClosed.

    function dismissPopup(notifId) {
        const e = _live[notifId]
        if (e?.notifData) e.notifData.dismiss()
        else popupDismissRequested(notifId)
    }

    function expirePopup(notifId) {
        const e = _live[notifId]
        if (e?.notifData) e.notifData.expire()
        else popupDismissRequested(notifId)
    }

    function dismissAllActive() {
        for (const id of _order.slice()) dismissPopup(id)
    }

    // Actions. Quickshell's NotificationAction::invoke() closes the
    // notification itself UNLESS the `resident` hint is set — so this must not
    // tear anything down: for non-resident the closed() signal arrives and
    // _onClosed does it, and for resident the popup is supposed to stay.
    function invokeAction(notifId, actionId) {
        const e = _live[notifId]
        if (!e?.notifData) {
            ToastService.info("Notification is no longer active")
            return
        }
        e.notifData.invokeAction(actionId)
    }

    function isLive(notifId) {
        return _live[notifId] !== undefined
    }

    function activeDuration(notifId) {
        return _live[notifId]?.notifData?.durationMs ?? 0
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
        const entryId = contentId + ":" + timestamp.toString(16) + ":" + (_nextEntryId++)
        return Object.assign({
            // `notificationId` is the HISTORY ROW key and keeps its name: it is
            // what persisted notification-history.json files already contain.
            // `notifId` is the live server-side Notification.id — a different
            // thing with a different lifetime, which is exactly why both exist.
            "id": entryId,
            "notificationId": entryId,
            "notifId": notification.id,
            "contentId": contentId,
            "timestamp": timestamp,
            "count": 1,
            "unread": true
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

    // ── History delegations (UI binds through the facade) ─────────
    function removeFromHistory(id)  { return NotificationHistory.removeUndoable(id) }
    function removeGroupFromHistory(appName) { NotificationHistory.removeGroup(appName) }
    function clearHistory()         { return NotificationHistory.clearUndoable() }
    function undoClearHistory()     { return NotificationHistory.undoClear() }
    function refreshClearUndo()     { NotificationHistory.refreshUndo() }
    readonly property bool canUndoClear: NotificationHistory.canUndoClear
    readonly property bool historyClearing: NotificationHistory.clearing
    readonly property bool historyRestoring: NotificationHistory.restoring
    readonly property int clearedHistoryCount: NotificationHistory.undoCount
    function isGroupExpanded(name)  { return NotificationHistory.isGroupExpanded(name) }
    function toggleGroupExpanded(n) { NotificationHistory.toggleGroupExpanded(n) }
    function getGroupCount(name)    { return NotificationHistory.getGroupCount(name) }
    function getGroupIcon(name)     { return NotificationHistory.getGroupIcon(name) }
    function markAllRead()          { NotificationHistory.markAllRead() }
    readonly property var historyList: NotificationHistory.historyList
    readonly property int unreadCount: NotificationHistory.unreadCount

    // Invoking an action from a history row: only possible while the
    // underlying notification is still live.
    function invokeActionFromHistory(notifId, actionId) {
        invokeAction(notifId, actionId)
    }

    // DND facade — state lives in NotificationDND, UI toggles via function.
    readonly property bool doNotDisturb: NotificationDND.enabled
    function toggleDoNotDisturb() { NotificationDND.toggle() }

    // ── IPC ───────────────────────────────────────────────────────
    IpcHandler {
        target: "notifications"

        function toggleDnd(): bool {
            NotificationDND.toggle()
            return NotificationDND.enabled
        }
        function setDnd(enabled: bool): void {
            NotificationDND.setEnabled(enabled)
        }
        function setDndFor(minutes: int): bool { return NotificationDND.setForMinutes(minutes) }
        function dndUntil(): string { return NotificationDND.temporary ? new Date(NotificationDND.expiresAt).toISOString() : "" }
        function isDnd(): bool {
            return NotificationDND.enabled
        }
        function dndActive(): bool {
            return NotificationDND.active
        }
        function dismissAll(): void {
            root.dismissAllActive()
        }
        function clear(): void {
            NotificationHistory.clear()
        }
        function undoClear(): bool { return NotificationHistory.undoClear() }
        function canUndoClear(): bool { NotificationHistory.refreshUndo(); return NotificationHistory.canUndoClear }
        function markAllRead(): void {
            NotificationHistory.markAllRead()
        }
        function count(): int {
            return NotificationHistory.historyList.count
        }
        function unread(): int {
            return NotificationHistory.unreadCount
        }
        function activeCount(): int {
            return root._order.length
        }
    }
}
