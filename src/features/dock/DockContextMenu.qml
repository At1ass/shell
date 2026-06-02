pragma ComponentBehavior: Bound

import QtQuick
import qs.src.core.config
import qs.src.core.services
import qs.src.ui.feedback

// In-window context menu, rendered inside the dock PanelWindow (like DockPreview).
// Input works reliably because the dock window's mask includes `menuRect` while open
// — the same mechanism the preview uses. Dismissal (click-outside) is handled by a
// HyprlandFocusGrab in Dock.qml. App-level actions only; per-window actions live in
// the hover preview.
Item {
    id: root
    anchors.fill: parent

    property var app: null
    property var _actions: []
    property bool placeBelow: false    // dock at top → menu opens below the icon
    property real iconCenterX: 0
    property real iconTopY: 0          // icon top edge, in dock-window coords
    property real iconBottomY: 0       // icon bottom edge, in dock-window coords

    readonly property bool open: menu.visible
    readonly property rect menuRect: Qt.rect(menu.x, menu.y, menu.width, menu.height)
    readonly property alias menuItem: menu   // for the dock's input mask region
    readonly property int _gap: Tokens.spacing.extraSmall
    readonly property int _margin: Tokens.spacing.small

    function openFor(appItem, iconRect) {
        if (!appItem) return
        app = appItem
        iconCenterX = iconRect.x + iconRect.width / 2
        iconTopY = iconRect.y
        iconBottomY = iconRect.y + iconRect.height

        let m = []
        let acts = []

        if (appItem.entry) {
            m.push({ label: "New window", icon: "open_in_new" })
            acts.push(() => DockService.launch(appItem))
        }

        const pinned = DockService.isPinned(appItem.appId)
        m.push({ label: pinned ? "Unpin from dock" : "Pin to dock", icon: pinned ? "keep_off" : "keep" })
        acts.push(() => pinned ? DockService.unpin(appItem.appId) : DockService.pin(appItem.appId))

        const count = (appItem.windows || []).length
        if (count > 0) {
            m.push({ separator: true }); acts.push(null)
            m.push({ label: count > 1 ? "Close all" : "Close", icon: "close" })
            acts.push(() => DockService.closeApp(appItem))
        }

        _actions = acts
        menu.model = m
        menu.visible = true
    }

    function close() {
        menu.visible = false
        app = null
    }

    MaterialMenu {
        id: menu
        visible: false

        x: Math.max(root._margin,
                    Math.min(root.iconCenterX - width / 2, root.width - width - root._margin))
        y: root.placeBelow ? (root.iconBottomY + root._gap)
                           : (root.iconTopY - height - root._gap)

        opacity: visible ? 1 : 0
        scale: visible ? 1 : 0.95
        transformOrigin: root.placeBelow ? Item.Top : Item.Bottom

        Behavior on opacity {
            NumberAnimation { duration: Tokens.motion.duration.short3 }
        }
        Behavior on scale {
            NumberAnimation {
                duration: Tokens.motion.duration.short4
                easing.type: Tokens.motion.easing.emphasizedDecelerate
                easing.bezierCurve: Tokens.motion.easing.emphasizedDeceleratePoints
            }
        }

        onTriggered: (index) => {
            const fn = root._actions[index]
            root.close()
            if (fn) fn()
        }
    }
}
