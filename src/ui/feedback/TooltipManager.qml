import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.src.core.config

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
        lastActiveItem.targetVisible = false
    }

    function onHidden(item: TooltipItem) {
        if (item == lastActiveItem) {
            lastActiveItem = null
        }
    }

    Timer {
        id: hangTimer
        interval: root.hangTime
        onTriggered: doLastHide()
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
        activeAsync: shownItem != null

        PopupWindow {
            id: popup

            anchor {
                window: bar
                rect.x: tooltipItem.targetX
                rect.y: bar.height + Tokens.spacing.small
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
            implicitWidth: Math.max(tooltipItem.targetWidth, activeItem?.isMenu ? 150 : 100)
			// width: Math.max(700, tooltipItem.largestAnimWidth) // max due to qtwayland glitches
            implicitHeight: Math.max(tooltipItem.targetHeight, 40)
            visible: true
            color: "transparent"

            mask: Region {
                item: (shownItem?.hoverable ?? false) ? tooltipItem : null
            }

            HyprlandFocusGrab {
                active: activeItem?.isMenu ?? false
                windows: [ popup, bar, ...(activeItem?.grabWindows ?? []) ]
                onActiveChanged: {
                    if (!active && activeItem?.isMenu) {
                        activeMenu.close()
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
                    origin.x: tooltipItem.width / 2
                    origin.y: 0
                    xScale: 0.8 + scaleMul * 0.2
                    yScale: xScale
                }

                readonly property real targetWidth: shownItem ? Math.max(shownItem.implicitWidth || 150, shownItem.isMenu ? 150 : 100) : 100
                readonly property real targetHeight: shownItem ? Math.max(shownItem.implicitHeight || 40, 40) : 40

                readonly property real targetX: {
                    if (shownItem == null || shownItem.owner == null) return 0
                    try {
                        const ownerGlobal = bar.contentItem.mapFromItem(shownItem.owner, 0, 0)
                        const targetCenter = ownerGlobal.x + shownItem.owner.width / 2
                        // Center the tooltip under the item, but keep it within bounds
                        const tooltipLeft = targetCenter - targetWidth / 2
                        const screenMargin = Tokens.spacing.medium
                        const maxLeft = bar.width - targetWidth - screenMargin

                        return Math.max(screenMargin, Math.min(maxLeft, tooltipLeft))
                    } catch (e) {
                        return Tokens.spacing.medium
                    }
                }

                x: 0
                y: 0
                width: targetWidth
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

                    // Primary tint
                    Rectangle {
                        anchors.fill: parent
                        color: Theme.primary
                        radius: parent.radius
                        opacity: Tokens.stateLayer.hoverOpacity
                    }
                }

                SmoothedAnimation on width {
                    id: widthAnim
                    to: tooltipItem.targetWidth
                    velocity: 800
                    duration: (shownItem?.animateSize ?? true) ? Tokens.motion.duration.short4 : 0
                }

                SmoothedAnimation on height {
                    id: heightAnim
                    to: tooltipItem.targetHeight
                    velocity: 800
                    duration: (shownItem?.animateSize ?? true) ? Tokens.motion.duration.short4 : 0
                }

                onTargetWidthChanged: {
                    if (shownItem?.animateSize ?? true) {
                        widthAnim.to = targetWidth
                        if (!widthAnim.running) widthAnim.start()
                    } else {
                        widthAnim.stop()
                        width = targetWidth
                    }
                }

                onTargetHeightChanged: {
                    if (shownItem?.animateSize ?? true) {
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
