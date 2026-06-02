pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.src.core.config
import qs.src.ui.containers

// The dock bar surface: an elevated MD3 container + the row/column of app icons.
// Owns the reveal scale/opacity animation; relays per-icon hover signals to the
// coordinator (Dock). Anchors/position are set by the parent on the instance.
Surface {
    id: root

    property var model: []
    property int iconSize: 48
    property int dockPadding: Tokens.spacing.small
    property int dockSpacing: Tokens.spacing.extraSmall
    property bool reveal: true
    property string position: "bottom"

    readonly property bool vertical: position === "left" || position === "right"

    signal requestPreview(int index, real center)
    signal cancelPreview(int index, real center)
    signal hoverEnded(int index)
    signal requestContextMenu(var app, var iconRect)
    signal requestReorder(int from, int to)

    width: dockLayout.implicitWidth + dockPadding * 2
    height: dockLayout.implicitHeight + dockPadding * 2

    elevation: 2                       // MD3: floating bar/menu surface
    radius: Tokens.shape.large
    color: Qt.alpha(Theme.surfaceContainer, 0.90)
    clip: false

    // Scale + opacity reveal (no translate — avoids Wayland clipping). Scales from the
    // dock's screen edge. MD3 emphasized: decelerate on appear, accelerate on hide.
    scale: reveal ? 1.0 : 0.85
    opacity: reveal ? 1.0 : 0.0
    transformOrigin: position === "bottom" ? Item.Bottom
                   : position === "top" ? Item.Top
                   : position === "left" ? Item.Left : Item.Right
    visible: opacity > 0

    Behavior on scale {
        NumberAnimation {
            duration: root.reveal ? Tokens.motion.duration.medium2 : Tokens.motion.duration.short4
            easing.type: root.reveal ? Tokens.motion.easing.emphasizedDecelerate
                                     : Tokens.motion.easing.emphasizedAccelerate
            easing.bezierCurve: root.reveal ? Tokens.motion.easing.emphasizedDeceleratePoints
                                            : Tokens.motion.easing.emphasizedAcceleratePoints
        }
    }
    Behavior on opacity {
        NumberAnimation { duration: Tokens.motion.duration.short4 }
    }

    // Primary surface tint (parent is Surface's content holder — use root.radius).
    Rectangle {
        anchors.fill: parent
        color: Theme.primary
        opacity: 0.08
        radius: root.radius
    }

    GridLayout {
        id: dockLayout
        anchors.centerIn: parent
        rowSpacing: root.dockSpacing
        columnSpacing: root.dockSpacing
        // One row (horizontal) or one column (vertical); the other axis is unbounded.
        rows: root.vertical ? -1 : 1
        columns: root.vertical ? 1 : -1

        Repeater {
            // ScriptModel diffs by reference against the stable DockService entry pool,
            // so delegates are reused (not recreated) across window events.
            model: ScriptModel { values: root.model }

            delegate: DockIcon {
                // Repeater fills `index` (DockIcon's own required prop) and `modelData` by name.
                required property var modelData

                app: modelData
                iconSize: root.iconSize
                dockSpacing: root.dockSpacing
                position: root.position
                showSeparator: !modelData.pinned && index > 0 && root.model[index - 1].pinned

                onRequestPreview: (i, c) => root.requestPreview(i, c)
                onCancelPreview: (i, c) => root.cancelPreview(i, c)
                onHoverEnded: (i) => root.hoverEnded(i)
                onRequestContextMenu: (a, r) => root.requestContextMenu(a, r)
                onRequestReorder: (f, t) => root.requestReorder(f, t)
            }
        }
    }
}
