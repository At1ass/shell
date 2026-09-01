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

    // How many live cards this surface holds. Also written by the manager, and
    // the ONLY thing `visible` is allowed to depend on.
    //
    // `visible` used to read `_appliedHeight > 0`, which closed a real cycle: a
    // card's height depends on its width (the body wraps), the width comes from
    // the window, and the window's geometry depends on `visible`. Qt reported it
    // as a binding loop on `visible`, reproducibly whenever a notification
    // carried an IMAGE -- the async load grows implicitHeight after the card is
    // already positioned, re-entering the chain mid-flight (see the manager's
    // implicitHeightChanged hookup). A count is a fact the manager already has
    // and no geometry can feed back into.
    property int popupCount: 0

    // Height handed to the layer surface. It GROWS with the stack and never
    // shrinks until the stack empties, because Hyprland animates layer-surface
    // geometry (`animation = layers`, easeOutQuint): a shrink leaves the strip
    // being animated away showing the surface's stale pixels, which read as a
    // card-shaped ghost fading out in the slot that was just vacated. Measured
    // by moving the shrink in time — the ghost followed it exactly.
    //
    // Staying oversized is free: the surface is transparent, and `mask` below
    // keeps its input region on the cards, so the empty part never swallows a
    // click. Being oversized is also what makes the stack safe to re-layout —
    // a card sliding up to its new slot can never be clipped by a surface that
    // is already at least as tall as every layout it passes through.
    property int _appliedHeight: 0

    onStackHeightChanged: {
        if (stackHeight === 0) _appliedHeight = 0
        else if (stackHeight > _appliedHeight) _appliedHeight = stackHeight
    }

    readonly property string position: AppConfig.notificationPopupPosition
    readonly property bool isTop: position.startsWith("top")
    readonly property bool isRight: position.endsWith("right")
    readonly property int baseMargin: isTop
        ? AppConfig.barHeight + AppConfig.barMargin
        : AppConfig.barMargin

    // Container the manager parents cards into.
    property alias cardLayer: cardLayer

    color: "transparent"
    visible: surface.popupCount > 0

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
    implicitHeight: Math.max(1, surface._appliedHeight)

    // Cards live in a box pinned to the anchored edge and sized to the stack,
    // not to the (deliberately oversized) surface. That keeps a bottom-anchored
    // stack against the bottom edge, and gives `mask` an exact content rect.
    Item {
        id: cardLayer
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: surface.isTop ? parent.top : undefined
        anchors.bottom: surface.isTop ? undefined : parent.bottom
        height: Math.max(0, surface.stackHeight)
    }

    // Input region = the cards, so the surface can be taller than its content
    // without eating clicks meant for the window underneath.
    mask: Region { item: cardLayer }
}
