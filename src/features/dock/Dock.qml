pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.src.core.config
import qs.src.core.services

// Dock coordinator: owns the PanelWindow, the Wayland input mask, the reveal/auto-hide
// state machine, and the preview show/hide timing. Presentation is delegated to
// DockBar (icons) and DockPreview (live window thumbnails).
PanelWindow {
    id: dock

    readonly property string screenName: screen ? screen.name : ""
    readonly property bool autoHide: AppConfig.dockAutoHide
    readonly property int iconSize: AppConfig.dockIconSize
    readonly property int dockPadding: Tokens.spacing.small
    readonly property int dockSpacing: Tokens.spacing.extraSmall

    // Position (horizontal orientation for now: bottom | top). Drives anchors, reveal
    // origin, preview/menu side, and the trigger-strip edge.
    readonly property string position: AppConfig.dockPosition
    readonly property bool atTop: position === "top"

    // The actual dock bar height
    readonly property int dockBarHeight: iconSize + 20 + dockPadding * 2

    // Reveal state — HoverHandler OR active preview OR open context menu keeps dock visible
    readonly property bool shouldReveal: !autoHide || dockHover.hovered || _previewShowing || contextMenu.open

    // === Model: pinned + running apps (computed once in DockService, shared across monitors) ===
    readonly property var dockModel: DockService.model

    // === Preview state machine ===
    property int _pendingPreviewIdx: -1
    property int _previewIdx: -1
    property real _previewCenterX: 0
    property bool _previewHovered: false
    readonly property int _previewThumbHeight: 180
    readonly property int _previewCardHeight: _previewThumbHeight + 26 + Tokens.spacing.medium * 2

    // Does NOT depend on shouldReveal — breaks feedback loop
    readonly property bool _previewShowing: _previewIdx >= 0 && _previewToplevels.length > 0

    readonly property var _previewToplevels: {
        if (_previewIdx < 0 || _previewIdx >= dockModel.length) return []
        return DockService.toplevelsFor(dockModel[_previewIdx])
    }

    readonly property string _previewFallbackIcon: {
        if (_previewIdx < 0 || _previewIdx >= dockModel.length) return ""
        return dockModel[_previewIdx]?.entry?.icon ?? ""
    }

    // Hover handlers from DockBar/DockIcon drive these.
    function _onPreviewRequest(index, centerX) {
        if (contextMenu.open) return   // menu takes precedence over hover preview
        previewHideTimer.stop()
        _previewCenterX = centerX
        _pendingPreviewIdx = index
        if (_previewIdx >= 0) {
            // Already showing — switch instantly
            _previewIdx = index
            previewShowTimer.stop()
        } else {
            // First reveal — use delay
            previewShowTimer.restart()
        }
    }

    function _onPreviewCancel(index) {
        previewShowTimer.stop()
        _pendingPreviewIdx = -1
        if (_previewIdx >= 0) previewHideTimer.restart()
    }

    function _onHoverEnded(index) {
        previewShowTimer.stop()
        if (_previewIdx === index || _pendingPreviewIdx === index)
            previewHideTimer.restart()
    }

    function _dismissPreview() {
        _previewIdx = -1
        _pendingPreviewIdx = -1
    }

    Timer {
        id: previewShowTimer
        interval: 400
        onTriggered: dock._previewIdx = dock._pendingPreviewIdx
    }

    Timer {
        id: previewHideTimer
        interval: 300
        onTriggered: {
            if (!dock._previewHovered) dock._dismissPreview()
        }
    }

    color: "transparent"
    exclusiveZone: AppConfig.dockExclusive ? dockBarHeight : 0
    WlrLayershell.namespace: "shell:dock"
    WlrLayershell.layer: WlrLayershell.Top

    // Input mask = union of the actual interactive rects (bar + preview + menu), each at
    // its own geometry — NOT a single bounding box. Clicks outside these precise rects pass
    // through (and clear the context-menu focus grab).
    mask: Region {
        Region { item: barMaskItem }
        Region { item: dock._previewShowing ? preview : null }
        Region { item: contextMenu.open ? contextMenu.menuItem : null }
    }

    anchors {
        left: true
        right: true
        top: dock.atTop
        bottom: !dock.atTop
    }

    // Height: always includes preview space when revealed.
    // The mask handles input passthrough, so the tall window doesn't block clicks.
    implicitHeight: {
        if (autoHide && !shouldReveal && bar.opacity < 0.01) return 4
        // Reserve space above the bar for the preview, or a taller context menu.
        const above = contextMenu.open
            ? Math.max(_previewCardHeight, contextMenu.menuRect.height + Tokens.spacing.small)
            : _previewCardHeight
        return dockBarHeight + above + Tokens.spacing.small
    }

    // Bar input rect, or a 1px trigger strip at the dock's screen edge when auto-hidden.
    // When revealed, the region extends all the way to that edge so the cursor at the very
    // edge stays within the input region (the bar floats `margin` away from it) — otherwise
    // reveal→cursor-in-gap→hide would flicker. (Preview and menu contribute their own
    // regions to the mask above.)
    Item {
        id: barMaskItem
        visible: false

        readonly property bool _strip: dock.autoHide && !dock.shouldReveal && bar.opacity < 0.01

        x: bar.x
        width: bar.width
        y: {
            if (dock.atTop) return 0
            return _strip ? dock.height - 1 : bar.y
        }
        height: {
            if (_strip) return 1
            return dock.atTop ? (bar.y + bar.height) : (dock.height - bar.y)
        }
    }

    // HoverHandler propagates through child MouseAreas — no flicker
    HoverHandler {
        id: dockHover
    }

    // === Preview popup ===
    DockPreview {
        id: preview
        model: dock._previewToplevels
        centerX: dock._previewCenterX
        showing: dock._previewShowing
        thumbHeight: dock._previewThumbHeight
        fallbackIcon: dock._previewFallbackIcon
        anchorItem: bar
        atTop: dock.atTop

        onHoverChanged: (hovered) => {
            dock._previewHovered = hovered
            if (hovered) previewHideTimer.stop()
            else previewHideTimer.restart()
        }
        onRequestDismiss: dock._dismissPreview()
    }

    // === Dock bar ===
    DockBar {
        id: bar
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: dock.atTop ? parent.top : undefined
        anchors.bottom: dock.atTop ? undefined : parent.bottom
        anchors.topMargin: dock.atTop ? Tokens.spacing.small : 0
        anchors.bottomMargin: dock.atTop ? 0 : Tokens.spacing.small

        model: dock.dockModel
        iconSize: dock.iconSize
        dockPadding: dock.dockPadding
        dockSpacing: dock.dockSpacing
        reveal: dock.shouldReveal
        atTop: dock.atTop
        activePreviewIndex: dock._previewIdx

        onRequestPreview: (index, centerX) => dock._onPreviewRequest(index, centerX)
        onCancelPreview: (index) => dock._onPreviewCancel(index)
        onHoverEnded: (index) => dock._onHoverEnded(index)
        onRequestContextMenu: (app, rect) => {
            dock._dismissPreview()
            contextMenu.openFor(app, rect)
        }
    }

    // === Right-click context menu (rendered in-window, on the icon's inner side) ===
    DockContextMenu {
        id: contextMenu
        placeBelow: dock.atTop
    }

    // Dismiss the context menu on click-outside. Grabs the dock window; clicks inside
    // its input region (bar/preview/menu) are delivered, clicks elsewhere clear the grab.
    HyprlandFocusGrab {
        active: contextMenu.open
        windows: [dock]
        onActiveChanged: {
            if (!active) contextMenu.close()
        }
    }
}
