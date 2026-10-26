pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.src.core.config

// One passive popup per bar. Geometry settles immediately; only content fades.
Scope {
    id: root
    required property var bar
    property bool suspended: false
    onSuspendedChanged: {
        showTimer.stop()
        hangTimer.stop()
        if (suspended) {
            const previous = shownItem
            shownItem = null
            if (previous) previous.hideImmediately()
        } else if (activeTooltip?.show) showTimer.restart()
    }
    property TooltipItem activeTooltip: null
    property TooltipItem shownItem: null
    property Item container: null
    readonly property real maximumWidth: Math.max(Tokens.spacing.large,
        Math.min(Tokens.size.fieldWidth + Tokens.spacing.large * 2,
                 (bar.screen?.width ?? bar.width) - Tokens.spacing.medium * 2))

    readonly property real maximumHeight: Math.max(Tokens.spacing.large,
        (bar.screen?.height ?? Tokens.size.listItem * 10) - bar.height - Tokens.spacing.medium * 2)

    function anchorOf(window) { return window.anchor }

    function setItem(item: TooltipItem) {
        if (activeTooltip === item) return
        hangTimer.stop()
        activeTooltip = item
        if (suspended) return
        if (shownItem === item) {
            if (container) item.reveal(container)
        } else showTimer.restart()
    }
    function removeItem(item: TooltipItem) {
        if (activeTooltip !== item) return
        activeTooltip = null
        showTimer.stop()
        if (shownItem) hangTimer.restart()
    }
    function present() {
        const item = activeTooltip
        if (suspended || !item || !item.show || !item.owner) return
        const previous = shownItem
        shownItem = item
        if (previous && previous !== item) previous.hideImmediately()
        if (container) item.reveal(container)
    }
    function onHidden(item: TooltipItem) {
        if (shownItem === item && activeTooltip !== item) shownItem = null
    }
    Timer { id: showTimer; interval: Tokens.interaction.tooltipDelay; onTriggered: root.present() }
    Timer {
        id: hangTimer
        interval: Tokens.interaction.tooltipDismissDelay
        onTriggered: if (root.shownItem) root.shownItem.targetVisible = false
    }
    LazyLoader {
        activeAsync: root.shownItem !== null
        PopupWindow {
            id: popup
            // _Window's metadata marks the anchor opaque; the helper keeps
            // the runtime object available to ordinary reactive Bindings.
            Binding { target: root.anchorOf(popup); property: "window"; value: root.bar }
            Binding {
                target: root.anchorOf(popup)
                property: "rect"
                // Unmapping is deferred by the native window. Keep the last
                // position until it is gone rather than moving to a null owner.
                when: root.shownItem !== null
                restoreMode: Binding.RestoreNone
                value: {
                    const owner = root.shownItem?.owner
                    const pos = owner ? root.bar.contentItem.mapFromItem(owner, 0, 0) : Qt.point(0, 0)
                    const left = Math.max(Tokens.spacing.medium,
                        Math.min(root.bar.width - popup.width - Tokens.spacing.medium,
                                 pos.x + (owner?.width ?? 0) / 2 - popup.width / 2))
                    return Qt.rect(left, AppConfig.barPosition === "bottom"
                        ? -Tokens.spacing.small : root.bar.height + Tokens.spacing.small, 0, 0)
                }
            }
            Binding { target: root.anchorOf(popup); property: "edges"; value: AppConfig.barPosition === "bottom" ? Edges.Top : Edges.Bottom }
            Binding { target: root.anchorOf(popup); property: "gravity"; value: (AppConfig.barPosition === "bottom" ? Edges.Top : Edges.Bottom) | Edges.Right }
            Binding { target: root.anchorOf(popup); property: "adjustment"; value: PopupAdjustment.Slide }
            implicitWidth: Tokens.spacing.small
            implicitHeight: Tokens.spacing.small
            // Preserve dimensions for the same unmap interval as the anchor.
            Binding {
                target: popup
                property: "implicitWidth"
                when: root.shownItem !== null
                restoreMode: Binding.RestoreNone
                value: Math.max(Tokens.spacing.small, Math.ceil(root.shownItem?.implicitWidth ?? 0))
            }
            Binding {
                target: popup
                property: "implicitHeight"
                when: root.shownItem !== null
                restoreMode: Binding.RestoreNone
                value: Math.max(Tokens.spacing.small, Math.ceil(root.shownItem?.implicitHeight ?? 0))
            }
            visible: root.shownItem !== null && root.bar.visible
            color: "transparent"
            mask: Region {}
            Item {
                id: content
                anchors.fill: parent
                Component.onCompleted: {
                    root.container = content
                    if (root.shownItem) root.shownItem.reveal(content)
                }
                Component.onDestruction: if (root.container === content) root.container = null
            }
        }
    }
}
