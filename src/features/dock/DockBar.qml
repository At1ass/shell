pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.src.core.config
import qs.src.ui.containers

// The dock bar surface: an elevated MD3 container + the row of app icons.
// Owns the reveal scale/opacity animation; relays per-icon hover signals to the
// coordinator (Dock). Anchors/position are set by the parent on the instance.
Surface {
    id: root

    property var model: []
    property int iconSize: 48
    property int dockPadding: Tokens.spacing.small
    property int dockSpacing: Tokens.spacing.extraSmall
    property bool reveal: true
    property bool atTop: false
    property int activePreviewIndex: -1

    signal requestPreview(int index, real centerX)
    signal cancelPreview(int index)
    signal hoverEnded(int index)
    signal requestContextMenu(var app, var iconRect)

    width: dockRow.implicitWidth + dockPadding * 2
    height: dockRow.implicitHeight + dockPadding * 2

    elevation: 2                       // MD3: floating bar/menu surface
    radius: Tokens.shape.large
    color: Qt.alpha(Theme.surfaceContainer, 0.90)
    clip: false

    // Scale + opacity reveal (no translate — avoids Wayland clipping). MD3 emphasized:
    // decelerate on appear, accelerate on hide.
    scale: reveal ? 1.0 : 0.85
    opacity: reveal ? 1.0 : 0.0
    transformOrigin: atTop ? Item.Top : Item.Bottom
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

    RowLayout {
        id: dockRow
        anchors.centerIn: parent
        spacing: root.dockSpacing

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
                atTop: root.atTop
                activePreviewIndex: root.activePreviewIndex
                showSeparator: !modelData.pinned && index > 0 && root.model[index - 1].pinned

                onRequestPreview: (i, cx) => root.requestPreview(i, cx)
                onCancelPreview: (i) => root.cancelPreview(i)
                onHoverEnded: (i) => root.hoverEnded(i)
                onRequestContextMenu: (a, r) => root.requestContextMenu(a, r)
            }
        }
    }
}
