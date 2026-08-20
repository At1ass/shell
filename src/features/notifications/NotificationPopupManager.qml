import QtQuick
import Quickshell
import qs.src.core.services
import qs.src.core.config

// Renders the popup stack. PRESENTATIONAL ONLY: it creates, positions and
// destroys windows, and reports user intent back to NotificationService. It
// never closes a notification and never decides that one should go away.
//
// That rule is load-bearing. The maxVisible cap used to live here, and
// "evicting" a popup meant destroying its window — which left the notification
// tracked on the server for the rest of the session, leaking the Notification,
// its NotifData and any image-data pixmap, once per eviction. The cap now sits
// in NotificationService next to the code that can actually close things.
//
// Popups are keyed by `notifId` (server-side Notification.id).
Scope {
    id: manager

    property var popupWindows: []
    property var _destroyingSet: ({})  // notifId -> true
    // screen name -> NotificationPopupSurface. One layer-shell surface per
    // screen now hosts the whole stack; cards are Items inside it. See
    // NotificationPopupSurface for why.
    property var _surfaces: ({})
    readonly property string position: AppConfig.notificationPopupPosition
    readonly property bool isTop: position.startsWith("top")
    readonly property int topMargin: AppConfig.barHeight + AppConfig.barMargin
    readonly property int bottomMargin: AppConfig.barMargin
    readonly property int baseMargin: isTop ? topMargin : bottomMargin
    readonly property int popupSpacing: 8

    property Component popupComponent: Component {
        NotificationPopup {}
    }

    property Component surfaceComponent: Component {
        NotificationPopupSurface {}
    }

    function _surfaceFor(scr) {
        const key = scr?.name ?? ""
        let s = _surfaces[key]
        if (!s) {
            s = surfaceComponent.createObject(manager, { "screen": scr })
            _surfaces[key] = s
        }
        return s
    }

    Connections {
        target: NotificationService

        function onPopupRequested(notifId, data) {
            manager._createPopup(notifId, data)
        }
        function onPopupUpdated(notifId, newNotifId, data) {
            manager._updatePopup(notifId, newNotifId, data)
        }
        function onPopupDismissRequested(notifId) {
            manager._beginExit(notifId)
        }
    }

    // Which output a NEW popup opens on (`notifications.popup.monitor`).
    //
    // A pinned output wins outright. Otherwise "focused" — but a stack that is
    // already on screen keeps its output instead of following the pointer
    // mid-burst: popups never migrate once mapped, so letting each card pick
    // its own monitor split one logical stack across two screens, each column
    // restarting at the top margin, while the maxVisible cap counted them
    // globally and evicted from whichever screen the user was not looking at.
    function _targetScreen() {
        const pinned = AppConfig.notificationPopupMonitor
        if (pinned && pinned !== "focused") {
            for (const s of Quickshell.screens) {
                if (s.name === pinned) return s
            }
            // Named output not connected (unplugged, typo). Fall through to the
            // focused monitor rather than dropping the notification on the floor.
        }
        return _stackScreen() ?? GlobalStates.focusedScreen()
    }

    // Output of the popups currently on screen, or null when the stack is empty.
    function _stackScreen() {
        for (let i = 0; i < popupWindows.length; i++) {
            const p = popupWindows[i]
            if (!p || _destroyingSet[p.notifId]) continue
            const s = manager._surfaces[p.screenName]
            if (s && s.screen) return s.screen
        }
        return null
    }

    function _findPopup(notifId) {
        for (let i = 0; i < popupWindows.length; i++) {
            const p = popupWindows[i]
            if (p && p.notifId === notifId) return p
        }
        return null
    }

    function _createPopup(notifId, data) {
        const scr = _targetScreen()
        const surface = _surfaceFor(scr)
        const popup = popupComponent.createObject(surface.cardLayer, {
            "notifId": notifId,
            "notificationData": data,
            "y": 0
        })
        // Remembered so the stack can be grouped per screen without asking a
        // card which window it is in — it no longer is one.
        popup.screenName = scr?.name ?? ""

        popup.exitFinished.connect(() => manager._onPopupExitFinished(popup))
        // Async image loads grow popupItem.implicitHeight after the popup is
        // already positioned. Re-stack so siblings below shift down instead of
        // being overlapped.
        popup.implicitHeightChanged.connect(manager._recalculateStack)

        popupWindows = [popup].concat(popupWindows)
        _recalculateStack()
    }

    // `newNotifId` differs when a duplicate merged into this popup: the card
    // stays on screen and simply re-keys onto the newer notification, so a
    // repeat shows as a count instead of a card swap.
    function _updatePopup(notifId, newNotifId, data) {
        const popup = _findPopup(notifId)
        if (!popup) return
        if (newNotifId !== notifId) {
            if (_destroyingSet[notifId]) {
                delete _destroyingSet[notifId]
                _destroyingSet[newNotifId] = true
            }
            popup.notifId = newNotifId
        }
        popup.updateData(data)
    }

    function _beginExit(notifId) {
        if (_destroyingSet[notifId]) return
        const popup = _findPopup(notifId)
        if (!popup) return
        _destroyingSet[notifId] = true
        popup.startExit()
    }

    function _onPopupExitFinished(popup) {
        delete _destroyingSet[popup.notifId]
        popupWindows = popupWindows.filter(p => p !== popup)
        _recalculateStack()
        Qt.callLater(() => { popup.destroy() })
    }

    function _recalculateStack() {
        // Independent column per screen — a single global accumulator
        // floated screen B's popups by the height of screen A's stack.
        // Offsets are now RELATIVE TO THE SURFACE, which already sits at
        // baseMargin, so the column starts at 0.
        const yByScreen = ({})
        for (let i = 0; i < popupWindows.length; i++) {
            const popup = popupWindows[i]
            if (!popup) continue
            if (_destroyingSet[popup.notifId]) continue
            const key = popup.screenName ?? ""
            if (yByScreen[key] === undefined) yByScreen[key] = 0
            popup.y = yByScreen[key]
            yByScreen[key] += (popup.implicitHeight > 0 ? popup.implicitHeight : 100) + popupSpacing
        }
        // Surface height follows the stack; trailing spacing is not part of it.
        for (const key in manager._surfaces) {
            const total = yByScreen[key]
            manager._surfaces[key].stackHeight =
                total === undefined ? 0 : Math.max(0, total - popupSpacing)
        }
    }
}
