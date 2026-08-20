import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.src.core.config

// ONE layer-shell surface per screen, hosting the whole popup stack.
//
// Each popup used to be its own PanelWindow positioned by `margins.top`, and
// the stack slide animated that margin. Every frame of a 250 ms slide is a
// zwlr_layer_surface_v1.set_margin plus a commit, and each one makes the
// compositor re-arrange the layer surfaces on that output. Measured with
// WAYLAND_DEBUG: 84 set_margin calls for four notifications, the margin
// creeping a pixel at a time (…195, 196…).
//
// With the cards living INSIDE one surface, the slide is a plain `y`
// animation on an Item: entirely client-side, zero protocol traffic. The
// surface only reconfigures when the stack's total height changes, i.e. once
// per card added or removed. It also collapses N surfaces into one.
//
// The surface is exactly as wide as a card and as tall as the stack, so the
// only input it swallows that previously passed through is the 8 px gap
// between cards.
PanelWindow {
    id: surface

    // Total height of the stack; the manager keeps it in sync.
    property int stackHeight: 0

    readonly property string position: AppConfig.notificationPopupPosition
    readonly property bool isTop: position.startsWith("top")
    readonly property bool isRight: position.endsWith("right")
    readonly property int baseMargin: isTop
        ? AppConfig.barHeight + AppConfig.barMargin
        : AppConfig.barMargin

    // Container the manager parents cards into.
    property alias cardLayer: cardLayer

    color: "transparent"
    visible: stackHeight > 0

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "shell:notification-popup"
    exclusiveZone: 0
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors {
        top: surface.isTop
        bottom: !surface.isTop
        right: surface.isRight
        left: !surface.isRight
    }

    margins {
        top: surface.isTop ? surface.baseMargin : 0
        bottom: !surface.isTop ? surface.baseMargin : 0
        right: surface.isRight ? AppConfig.barMargin : 0
        left: !surface.isRight ? AppConfig.barMargin : 0
    }

    implicitWidth: AppConfig.notificationPopupWidth
    // 1 rather than 0: a zero-sized layer surface is not a legal configure.
    implicitHeight: Math.max(1, surface.stackHeight)

    Item {
        id: cardLayer
        anchors.fill: parent
    }
}
