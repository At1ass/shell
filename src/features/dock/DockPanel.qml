pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.src.core.config
import qs.src.core.services

// The dock PanelWindow: owns the Wayland input mask, the reveal/auto-hide state machine,
// and the preview show/hide timing. Presentation is delegated to DockBar (icons) and
// DockPreview (live window thumbnails). Created (and recreated on position change) by Dock.
//
// Position-aware (bottom | top | left | right): the single source of layout truth, it
// computes the orientation/edge and passes `position` to the children.
PanelWindow {
    id: dock

    readonly property string screenName: screen ? screen.name : ""
    readonly property bool autoHide: AppConfig.dockAutoHide
    readonly property int iconSize: AppConfig.dockIconSize
    readonly property int dockPadding: Tokens.spacing.small
    readonly property int dockSpacing: Tokens.spacing.extraSmall

    // The bar's cross-axis thickness (height for a horizontal dock, width for vertical).
    readonly property int dockBarHeight: iconSize + 20 + dockPadding * 2

    // === Position ===
    readonly property string position: AppConfig.dockPosition   // bottom | top | left | right
    readonly property bool isVertical: position === "left" || position === "right"

    // Reveal state — HoverHandler OR active preview OR open context menu keeps dock visible
    readonly property bool shouldReveal: !autoHide || dockHover.hovered || _previewShowing || contextMenu.open

    // === Model: pinned + running apps (computed once in DockService, shared across monitors) ===
    readonly property var dockModel: DockService.model

    // === Hover (drives both the preview and the tooltip) ===
    property int _hoverIndex: -1
    property real _hoverCenter: 0

    readonly property string _tooltipText: {
        if (_hoverIndex < 0 || _hoverIndex >= dockModel.length) return ""
        const it = dockModel[_hoverIndex]
        const name = it.entry?.name ?? it.appId
        const count = it.windows.length
        return count > 1 ? (name + " (" + count + ")") : name
    }
    readonly property bool _tooltipVisible: _hoverIndex >= 0 && !_previewShowing
                                            && !contextMenu.open && shouldReveal

    // === Preview state machine ===
    property int _pendingPreviewIdx: -1
    property int _previewIdx: -1
    property real _previewCenter: 0          // along-axis center (x for horizontal, y for vertical)
    property bool _previewHovered: false
    readonly property int _previewThumbHeight: 180
    readonly property int _previewCardHeight: _previewThumbHeight + 26 + Tokens.spacing.medium * 2

    // Reserve toward the screen centre for preview/menu (thickness-axis inner extent).
    readonly property int _innerReserve: isVertical
        ? Math.min((screen ? screen.width : 1920) * 0.4, 720)
        : _previewCardHeight
    readonly property real _menuExtent: isVertical ? contextMenu.menuRect.width : contextMenu.menuRect.height

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

    // Hover handlers from DockBar/DockIcon drive preview + tooltip.
    function _onPreviewRequest(index, center) {
        _hoverIndex = index
        _hoverCenter = center
        if (contextMenu.open) return   // menu takes precedence over hover preview
        previewHideTimer.stop()
        _previewCenter = center
        _pendingPreviewIdx = index
        if (_previewIdx >= 0) {
            _previewIdx = index           // already showing — switch instantly
            previewShowTimer.stop()
        } else {
            previewShowTimer.restart()    // first reveal — use delay
        }
    }

    function _onPreviewCancel(index, center) {
        _hoverIndex = index
        _hoverCenter = center
        previewShowTimer.stop()
        _pendingPreviewIdx = -1
        if (_previewIdx >= 0) previewHideTimer.restart()
    }

    function _onHoverEnded(index) {
        if (_hoverIndex === index) _hoverIndex = -1
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

    anchors {
        left: !dock.isVertical || dock.position === "left"
        right: !dock.isVertical || dock.position === "right"
        top: dock.isVertical || dock.position === "top"
        bottom: dock.isVertical || dock.position === "bottom"
    }

    // Thickness-axis extent (reserves bar + inner space for preview/menu). The other axis
    // is stretched by the anchors. Collapses to 4px when auto-hidden.
    readonly property int _thicknessExtent: {
        if (autoHide && !shouldReveal && bar.opacity < 0.01) return 4
        const inner = contextMenu.open
            ? Math.max(_innerReserve, _menuExtent + Tokens.spacing.small)
            : _innerReserve
        return dockBarHeight + inner + Tokens.spacing.small
    }
    // The thickness axis uses _thicknessExtent; the stretched axis is 0 = "no preference,
    // let the left+right (or top+bottom) anchors size it". A non-zero value here conflicts
    // with the anchors and breaks the surface. Position changes recreate the window (Dock
    // wrapper), so the 0↔value transition never happens on a live surface.
    implicitWidth: isVertical ? _thicknessExtent : 0
    implicitHeight: isVertical ? 0 : _thicknessExtent

    // Input mask = union of the actual interactive rects (bar + preview + menu), each at
    // its own geometry — NOT a single bounding box. Clicks outside these precise rects pass
    // through (and clear the context-menu focus grab).
    mask: Region {
        Region { item: barMaskItem }
        Region { item: dock._previewShowing ? preview : null }
        Region { item: contextMenu.open ? contextMenu.menuItem : null }
    }

    // Bar input rect, or a 1px trigger strip at the dock's screen edge when auto-hidden.
    // The thickness axis reaches the screen edge so the cursor at the very edge stays in
    // the region (the bar floats `margin` away) — otherwise reveal→gap→hide would flicker.
    Item {
        id: barMaskItem
        visible: false

        readonly property bool _strip: dock.autoHide && !dock.shouldReveal && bar.opacity < 0.01

        x: {
            if (dock.position === "left") return 0
            if (dock.position === "right") return _strip ? dock.width - 1 : bar.x
            return bar.x
        }
        y: {
            if (dock.position === "top") return 0
            if (dock.position === "bottom") return _strip ? dock.height - 1 : bar.y
            return bar.y
        }
        width: {
            if (dock.isVertical) {
                if (_strip) return 1
                return dock.position === "left" ? (bar.x + bar.width) : (dock.width - bar.x)
            }
            return bar.width
        }
        height: {
            if (!dock.isVertical) {
                if (_strip) return 1
                return dock.position === "top" ? (bar.y + bar.height) : (dock.height - bar.y)
            }
            return bar.height
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
        center: dock._previewCenter
        showing: dock._previewShowing
        thumbHeight: dock._previewThumbHeight
        fallbackIcon: dock._previewFallbackIcon
        anchorItem: bar
        position: dock.position

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
        anchors.horizontalCenter: dock.isVertical ? undefined : parent.horizontalCenter
        anchors.verticalCenter: dock.isVertical ? parent.verticalCenter : undefined
        anchors.top: dock.position === "top" ? parent.top : undefined
        anchors.bottom: dock.position === "bottom" ? parent.bottom : undefined
        anchors.left: dock.position === "left" ? parent.left : undefined
        anchors.right: dock.position === "right" ? parent.right : undefined
        anchors.margins: Tokens.spacing.small

        model: dock.dockModel
        iconSize: dock.iconSize
        dockPadding: dock.dockPadding
        dockSpacing: dock.dockSpacing
        reveal: dock.shouldReveal
        position: dock.position

        onRequestPreview: (index, center) => dock._onPreviewRequest(index, center)
        onCancelPreview: (index, center) => dock._onPreviewCancel(index, center)
        onHoverEnded: (index) => dock._onHoverEnded(index)
        onRequestContextMenu: (app, rect) => {
            dock._dismissPreview()
            contextMenu.openFor(app, rect)
        }
        onRequestReorder: (from, to) => DockService.reorder(from, to)
    }

    // === Hover tooltip (app name) ===
    DockTooltip {
        text: dock._tooltipText
        center: dock._hoverCenter
        showing: dock._tooltipVisible
        anchorItem: bar
        position: dock.position
    }

    // === Right-click context menu (rendered in-window, on the icon's inner side) ===
    DockContextMenu {
        id: contextMenu
        anchorItem: bar
        position: dock.position
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
