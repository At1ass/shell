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

    readonly property ShellScreen _screen: screen as ShellScreen
    readonly property string screenName: _screen?.name ?? ""
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

    // Hover and delayed preview targets are identities, independent of list order.
    property string _hoverKey: ""
    property real _hoverCenter: 0
    readonly property var _hoverApp: DockService.entryForKey(_hoverKey)

    readonly property string _tooltipText: {
        if (!_hoverApp) return ""
        const name = _hoverApp.entry?.name ?? _hoverApp.appId
        const count = _hoverApp.windows.length
        return count > 1 ? (name + " (" + count + ")") : name
    }
    readonly property bool _tooltipVisible: _hoverApp !== null && !_previewShowing
                                            && !contextMenu.open && shouldReveal

    // === Preview state machine ===
    property string _pendingPreviewKey: ""
    property string _previewKey: ""
    readonly property var _pendingPreviewApp: DockService.entryForKey(_pendingPreviewKey)
    readonly property var _previewApp: DockService.entryForKey(_previewKey)
    // Cleanup follows model publication, outside the derived lookup bindings.
    onDockModelChanged: {
        if (_hoverKey && !DockService.entryForKey(_hoverKey)) _hoverKey = ""
        if (_pendingPreviewKey && !DockService.entryForKey(_pendingPreviewKey)) {
            previewShowTimer.stop()
            _pendingPreviewKey = ""
        }
        if (_previewKey && !DockService.entryForKey(_previewKey)) {
            _previewKey = ""
            _previewHovered = false
        }
    }
    property real _previewCenter: 0          // along-axis center (x for horizontal, y for vertical)
    property bool _previewHovered: false
    readonly property int _previewThumbHeight: 180
    readonly property int _previewCardHeight: _previewThumbHeight + 26 + Tokens.spacing.medium * 2

    // Reserve toward the screen centre for preview/menu (thickness-axis inner extent).
    readonly property int _availableInner: Math.max(0,
        (isVertical ? (_screen?.width ?? 1920) : (_screen?.height ?? 1080))
            - dockBarHeight - Tokens.spacing.small * 2)
    readonly property int _innerReserve: Math.min(_availableInner, isVertical
        ? Math.min((_screen?.width ?? 1920) * 0.4, 720)
        : _previewCardHeight)
    readonly property real _menuExtent: isVertical ? contextMenu.menuRect.width : contextMenu.menuRect.height

    // Does NOT depend on shouldReveal — breaks feedback loop
    readonly property bool _previewShowing: _previewApp !== null && _previewToplevels.length > 0
    readonly property var _previewToplevels: DockService.toplevelsFor(_previewApp)
    readonly property string _previewFallbackIcon: _previewApp?.entry?.icon ?? ""

    // Enter(new) may arrive before exit(old). Compare stable keys in every path.
    function _onPreviewRequest(key, center) {
        if (!DockService.entryForKey(key)) return
        _hoverKey = key
        _hoverCenter = center
        if (contextMenu.open) return
        previewHideTimer.stop()
        _previewCenter = center
        _pendingPreviewKey = key
        if (_previewKey !== "") {
            _previewKey = key
            _pendingPreviewKey = ""
            previewShowTimer.stop()
        } else {
            previewShowTimer.restart()
        }
    }

    function _onPreviewCancel(key, center) {
        if (!DockService.entryForKey(key)) return
        _hoverKey = key
        _hoverCenter = center
        previewShowTimer.stop()
        _pendingPreviewKey = ""
        if (_previewKey !== "") previewHideTimer.restart()
    }

    function _onHoverEnded(key) {
        if (!key) return
        if (_hoverKey === key) _hoverKey = ""
        if (_pendingPreviewKey === key) {
            previewShowTimer.stop()
            _pendingPreviewKey = ""
        }
        if (_previewKey === key) previewHideTimer.restart()
    }

    function _dismissPreview() {
        previewShowTimer.stop()
        previewHideTimer.stop()
        _previewKey = ""
        _pendingPreviewKey = ""
        _previewHovered = false
    }

    Timer {
        id: previewShowTimer
        interval: Tokens.interaction.tooltipDelay
        onTriggered: {
            if (dock._pendingPreviewApp && dock._hoverKey === dock._pendingPreviewKey && !contextMenu.open)
                dock._previewKey = dock._pendingPreviewKey
            dock._pendingPreviewKey = ""
        }
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
    WlrLayershell.layer: WlrLayer.Top

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
        x: dock.isVertical
            ? (dock.position === "left" ? Tokens.spacing.small : parent.width - width - Tokens.spacing.small)
            : (parent.width - width) / 2
        y: dock.isVertical ? (parent.height - height) / 2
            : (dock.position === "top" ? Tokens.spacing.small : parent.height - height - Tokens.spacing.small)

        model: dock.dockModel
        iconSize: dock.iconSize
        dockPadding: dock.dockPadding
        dockSpacing: dock.dockSpacing
        reveal: dock.shouldReveal
        position: dock.position

        onRequestPreview: (key, center) => dock._onPreviewRequest(key, center)
        onCancelPreview: (key, center) => dock._onPreviewCancel(key, center)
        onHoverEnded: (key) => dock._onHoverEnded(key)
        onRequestContextMenu: (app, rect) => {
            dock._dismissPreview()
            contextMenu.openFor(app, rect)
        }
        onRequestReorder: (from, to) => DockService.reorder(from, to)
    }

    // === Hover tooltip (app name) ===
    DockTooltip {
        hintText: dock._tooltipText
        center: dock._hoverCenter
        showing: dock._tooltipVisible
        anchorItem: bar
        position: dock.position
    }

    // === Right-click context menu (rendered in-window, on the icon's inner side) ===
    DockContextMenu {
        id: contextMenu
        availableWidth: Math.max(0, (dock._screen?.width ?? 0)
            - (dock.isVertical ? dock.dockBarHeight : 0) - Tokens.spacing.small * 4)
        availableHeight: Math.max(0, (dock._screen?.height ?? 0)
            - (dock.isVertical ? 0 : dock.dockBarHeight) - Tokens.spacing.small * 4)
        anchorItem: bar
        position: dock.position
        onOpenChanged: {
            menuGrabTimer.stop()
            dock.menuGrabReady = false
            if (open) menuGrabTimer.restart()
        }
    }
    property bool menuGrabReady: false
    WlrLayershell.keyboardFocus: contextMenu.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    Timer {
        id: menuGrabTimer
        interval: Tokens.interaction.popupGrabDelay
        onTriggered: {
            dock.menuGrabReady = true
            contextMenu.focusInitial()
        }
    }

    // Dismiss the context menu on click-outside. Grabs the dock window; clicks inside
    // its input region (bar/preview/menu) are delivered, clicks elsewhere clear the grab.
    HyprlandFocusGrab {
        active: dock.visible && contextMenu.open && dock.menuGrabReady
        windows: [dock]
        onCleared: contextMenu.close()
    }
}
