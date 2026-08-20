pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.src.core.config
import qs.src.ui.containers

Scope {
    id: root
    required property var bar

    property TooltipItem activeTooltip: null
    property TooltipItem activeMenu: null

    readonly property TooltipItem activeItem: activeMenu ?? activeTooltip
    property TooltipItem lastActiveItem: null
    readonly property TooltipItem shownItem: activeItem ?? lastActiveItem
    property real hangTime: lastActiveItem?.hangTime ?? 0

    property Item tooltipItem: null

    onActiveItemChanged: {
        if (activeItem != null) {
            hangTimer.stop()
            activeItem.targetVisible = true

            if (tooltipItem) {
                activeItem.parent = tooltipItem
            }
        }

        if (lastActiveItem != null && lastActiveItem != activeItem) {
            if (activeItem != null) lastActiveItem.targetVisible = false
            else if (root.hangTime == 0) doLastHide()
            else hangTimer.start()
        }

        if (activeItem != null) lastActiveItem = activeItem
    }

    function setItem(item: TooltipItem) {
        if (item.isMenu) {
            activeMenu = item
        } else {
            activeTooltip = item
        }
    }

    function removeItem(item: TooltipItem) {
        if (item.isMenu && activeMenu == item) {
            activeMenu = null
        } else if (!item.isMenu && activeTooltip == item) {
            activeTooltip = null
        }
    }

    function doLastHide() {
        // The owning widget can be destroyed during the hang window
        // (config hot-reload rebuilds a bar section) — the typed property
        // auto-nulls and an unguarded write threw.
        if (lastActiveItem) lastActiveItem.targetVisible = false
    }

    function onHidden(item: TooltipItem) {
        if (item == lastActiveItem) {
            lastActiveItem = null
        }
    }

    onLastActiveItemChanged: {
        if (!lastActiveItem) hangTimer.stop()
    }

    Timer {
        id: hangTimer
        interval: root.hangTime
        onTriggered: root.doLastHide()
    }

    property real scaleMul: lastActiveItem && lastActiveItem.targetVisible ? 1 : 0
    Behavior on scaleMul {
        SmoothedAnimation {
            velocity: 6
            duration: Tokens.motion.duration.short4
        }
    }

    LazyLoader {
        id: popupLoader
        activeAsync: root.shownItem != null

        PopupWindow {
            id: popup

            anchor {
                window: root.bar
                rect.x: tooltipItem.targetX
                rect.y: root.bar.height + Tokens.spacing.small
                adjustment: PopupAdjustment.Slide
            }

            HyprlandWindow.opacity: root.scaleMul

            HyprlandWindow.visibleMask: Region {
                id: visibleMask
                item: tooltipItem
            }

            Connections {
                target: root

                function onScaleMulChanged() {
                    visibleMask.changed()
                }
            }

            // implicitWidth: Math.max(tooltipItem.targetWidth, activeItem?.isMenu ? 150 : 100)
            implicitWidth: Math.max(tooltipItem.targetWidth, root.activeItem?.isMenu ? 150 : 100)
			// width: Math.max(700, tooltipItem.largestAnimWidth) // max due to qtwayland glitches
            implicitHeight: Math.max(tooltipItem.targetHeight, 40)
            visible: true
            color: "transparent"

            mask: Region {
                item: (root.shownItem?.hoverable ?? false) ? tooltipItem : null
            }

            HyprlandFocusGrab {
                active: root.activeItem?.isMenu ?? false
                windows: [ popup, root.bar, ...(root.activeItem?.grabWindows ?? []) ]
                onActiveChanged: {
                    if (!active && root.activeItem?.isMenu) {
                        root.activeMenu.close()
                    }
                }
            }

            Item {
                id: tooltipItem
                Component.onCompleted: {
                    root.tooltipItem = this
                    if (root.shownItem) {
                        root.shownItem.parent = this
                    }
                }

                transform: Scale {
                    id: tooltipScale
                    origin.x: tooltipItem.width / 2
                    origin.y: 0
                    xScale: 0.8 + root.scaleMul * 0.2
                    yScale: tooltipScale.xScale
                }

                readonly property real targetWidth: root.shownItem ? Math.max(root.shownItem.implicitWidth || 150, root.shownItem.isMenu ? 150 : 100) : 100
                readonly property real targetHeight: root.shownItem ? Math.max(root.shownItem.implicitHeight || 40, 40) : 40

                readonly property real targetX: {
                    if (root.shownItem == null || root.shownItem.owner == null) return 0
                    try {
                        const ownerGlobal = root.bar.contentItem.mapFromItem(root.shownItem.owner, 0, 0)
                        const targetCenter = ownerGlobal.x + root.shownItem.owner.width / 2
                        // Center the tooltip under the item, but keep it within bounds
                        const tooltipLeft = targetCenter - tooltipItem.targetWidth / 2
                        const screenMargin = Tokens.spacing.medium
                        const maxLeft = root.bar.width - tooltipItem.targetWidth - screenMargin

                        return Math.max(screenMargin, Math.min(maxLeft, tooltipLeft))
                    } catch (e) {
                        return Tokens.spacing.medium
                    }
                }

                x: 0
                y: 0
                width: tooltipItem.targetWidth
                height: targetHeight

                // Background
                Rectangle {
                    anchors.fill: parent
                    color: Theme.surfaceContainerHigh
                    radius: Tokens.shape.large

                    // Elevation shadow effect
                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        border.color: Theme.outline
                        border.width: 1
                        radius: parent.radius
                        opacity: Tokens.stateLayer.focusOpacity
                    }

                    // Primary tint — from the elevation scale, not from the
                    // hover state-layer token it used to borrow.
                    SurfaceTint {
                        level: 2
                        radius: parent.radius
                    }
                }

                SmoothedAnimation on width {
                    id: widthAnim
                    to: tooltipItem.targetWidth
                    velocity: 800
                    duration: (root.shownItem?.animateSize ?? true) ? Tokens.motion.duration.short4 : 0
                }

                SmoothedAnimation on height {
                    id: heightAnim
                    to: tooltipItem.targetHeight
                    velocity: 800
                    duration: (root.shownItem?.animateSize ?? true) ? Tokens.motion.duration.short4 : 0
                }

                onTargetWidthChanged: {
                    if (root.shownItem?.animateSize ?? true) {
                        widthAnim.to = tooltipItem.targetWidth
                        if (!widthAnim.running) widthAnim.start()
                    } else {
                        widthAnim.stop()
                        width = tooltipItem.targetWidth
                    }
                }

                onTargetHeightChanged: {
                    if (root.shownItem?.animateSize ?? true) {
                        heightAnim.to = targetHeight
                        if (!heightAnim.running) heightAnim.start()
                    } else {
                        heightAnim.stop()
                        height = targetHeight
                    }
                }
            }
        }
    }
}
