import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.src.core.services
import qs.src.core.config

Scope {
    id: manager

    property var popupWindows: []
    property var _destroyingSet: ({})  // notificationId -> true
    property int maxVisible: AppConfig.notificationPopupMaxVisible
    readonly property string position: AppConfig.notificationPopupPosition
    readonly property bool isTop: position.startsWith("top")
    readonly property int topMargin: AppConfig.barHeight + AppConfig.barMargin
    readonly property int bottomMargin: AppConfig.barMargin
    readonly property int baseMargin: isTop ? topMargin : bottomMargin
    readonly property int popupSpacing: 8

    // Follow-focused-monitor: each new popup spawns on the currently
    // focused screen. Existing popups stay on their original screen
    // (re-parenting mid-flight would cause animation flicker).
    function _getTargetScreen() {
        const focused = Hyprland.focusedMonitor
        if (focused) {
            for (const screen of Quickshell.screens) {
                if (screen.name === focused.name) return screen
            }
        }
        return Quickshell.screens[0]
    }

    property Component popupComponent: Component {
        NotificationPopup {}
    }

    Connections {
        target: NotificationService

        function onPopupRequested(data, notification) {
            manager._createPopup(data, notification)
        }

        function onPopupReplaced(notificationId, data) {
            manager._updatePopup(notificationId, data)
        }

        function onPopupDismissRequested(notificationId) {
            manager._beginDismiss(notificationId)
        }
    }

    function _createPopup(data, notification) {
        // Enforce maxVisible against popups NOT already dismissing (the old
        // loop broke on the first dismissing entry, letting bursts stack
        // beyond the cap). Oldest entries sit at the end of popupWindows.
        const live = popupWindows.filter(p => p && !_destroyingSet[p.notificationData?.notificationId])
        let toEvict = live.length - (maxVisible - 1)
        for (let i = live.length - 1; i >= 0 && toEvict > 0; i--, toEvict--) {
            _beginDismiss(live[i].notificationData.notificationId)
        }

        const targetScreen = _getTargetScreen()
        const popup = popupComponent.createObject(manager, {
            "notificationData": data,
            "notificationObject": notification,
            "screen": targetScreen,
            "screenY": baseMargin
        })

        popup.exitFinished.connect(() => manager._onPopupExitFinished(popup))
        // Async image loads grow popupItem.implicitHeight after the popup is
        // already positioned. Re-stack so siblings below shift down instead of
        // being overlapped.
        popup.implicitHeightChanged.connect(manager._recalculateStack)

        popupWindows = [popup].concat(popupWindows)
        NotificationService.registerPopup(data.notificationId)

        _recalculateStack()
    }

    function _updatePopup(notificationId, newData) {
        for (let i = 0; i < popupWindows.length; i++) {
            const popup = popupWindows[i]
            if (popup && popup.notificationData?.notificationId === notificationId) {
                popup.updateData(newData)
                return
            }
        }
    }

    function _beginDismiss(notificationId) {
        if (_destroyingSet[notificationId]) return

        for (let i = 0; i < popupWindows.length; i++) {
            const popup = popupWindows[i]
            if (popup && popup.notificationData?.notificationId === notificationId) {
                _destroyingSet[notificationId] = true
                popup.startExit()
                return
            }
        }
    }

    function _onPopupExitFinished(popup) {
        const id = popup.notificationData?.notificationId
        if (id) {
            delete _destroyingSet[id]
            NotificationService.unregisterPopup(id)
        }

        let arr = popupWindows.filter(p => p !== popup)
        popupWindows = arr

        _recalculateStack()

        Qt.callLater(() => { popup.destroy() })
    }

    function _recalculateStack() {
        let y = baseMargin
        for (let i = 0; i < popupWindows.length; i++) {
            const popup = popupWindows[i]
            if (!popup) continue
            if (_destroyingSet[popup.notificationData?.notificationId]) continue
            popup.screenY = y
            const h = (popup.implicitHeight > 0 ? popup.implicitHeight : 100) + popupSpacing
            y += h
        }
    }

}
