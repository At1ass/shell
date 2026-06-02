pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.src.core.config
import qs.src.core.services
import qs.src.ui.feedback

// One dock entry: app icon, running-window indicator dots, hover scale, tooltip.
// Presentational — left/middle clicks act via DockService; hover is reported up to
// the coordinator (Dock) which owns the preview state machine.
Item {
    id: root

    required property var app          // DockService.model item {key,appId,entry,windows,pinned,cls}
    required property int index
    property int iconSize: 48
    property int dockSpacing: 4
    property bool showSeparator: false
    property bool atTop: false
    property int activePreviewIndex: -1   // suppress tooltip while this icon's preview is shown

    // Running app hovered → request (delayed) preview at centerX (window coords).
    signal requestPreview(int index, real centerX)
    // Non-running icon hovered → cancel any pending preview.
    signal cancelPreview(int index)
    // Mouse left this icon.
    signal hoverEnded(int index)
    // Right-click → request context menu, with the icon's rect in window coords.
    signal requestContextMenu(var app, var iconRect)

    readonly property bool isActive: app.windows.length > 0
    readonly property bool isFocused: {
        for (let i = 0; i < app.windows.length; i++) {
            if (app.windows[i].activated) return true
        }
        return false
    }

    implicitWidth: (showSeparator ? separatorRect.width + dockSpacing : 0) + iconButton.width
    implicitHeight: iconSize + 12
    Layout.alignment: Qt.AlignVCenter

    Rectangle {
        id: separatorRect
        visible: root.showSeparator
        width: 1
        height: root.iconSize * 0.6
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        color: Qt.alpha(Theme.outline, 0.4)
    }

    Rectangle {
        id: iconButton
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: root.iconSize + 8
        height: root.iconSize + 8
        radius: Tokens.shape.medium
        color: "transparent"

        property bool hovered: iconMouseArea.containsMouse
        scale: hovered ? 1.1 : 1.0
        Behavior on scale {
            NumberAnimation {
                duration: Tokens.motion.duration.short3
                easing.type: Easing.OutBack
                easing.overshoot: 2
            }
        }

        Image {
            anchors.centerIn: parent
            width: root.iconSize
            height: root.iconSize
            source: {
                const icon = root.app.entry?.icon ?? ""
                if (icon) return "image://icon/" + icon
                return "image://icon/application-x-executable"
            }
            sourceSize: Qt.size(root.iconSize, root.iconSize)
            smooth: true
            opacity: root.isActive || root.app.pinned ? 1.0 : 0.5
        }

        StateLayer {
            layerColor: Theme.onSurface
            hovered: iconButton.hovered
            pressed: iconMouseArea.pressed
        }

        MouseArea {
            id: iconMouseArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor

            onContainsMouseChanged: {
                if (containsMouse && root.isActive) {
                    const pos = iconButton.mapToItem(null, iconButton.width / 2, 0)
                    root.requestPreview(root.index, pos.x)
                } else if (containsMouse) {
                    root.cancelPreview(root.index)
                } else {
                    root.hoverEnded(root.index)
                }
            }

            onClicked: (mouse) => {
                if (mouse.button === Qt.RightButton) {
                    const p = iconButton.mapToItem(null, 0, 0)
                    root.requestContextMenu(root.app,
                        Qt.rect(p.x, p.y, iconButton.width, iconButton.height))
                } else if (mouse.button === Qt.MiddleButton) {
                    DockService.launch(root.app)
                } else {
                    DockService.activateOrCycle(root.app)
                }
            }
        }

        // QtQuick.Controls ToolTip — no tooltipManager available in dock (replaced in Phase 4)
        ToolTip {
            visible: iconMouseArea.containsMouse && root.activePreviewIndex !== root.index
            text: {
                const name = root.app.entry?.name ?? root.app.appId
                const count = root.app.windows.length
                return count > 1 ? name + " (" + count + ")" : name
            }
            delay: 400
        }
    }

    // Running indicator dots — on the screen-edge side of the icon.
    Row {
        anchors.horizontalCenter: iconButton.horizontalCenter
        anchors.top: root.atTop ? undefined : iconButton.bottom
        anchors.bottom: root.atTop ? iconButton.top : undefined
        anchors.topMargin: root.atTop ? 0 : 1
        anchors.bottomMargin: root.atTop ? 1 : 0
        spacing: 3
        visible: root.isActive

        Repeater {
            model: Math.min(root.app.windows.length, 3)

            Rectangle {
                required property int index
                width: root.isFocused && index === 0 ? 10 : 4
                height: 4
                radius: 2
                color: root.isFocused ? Theme.primary : Theme.onSurfaceVariant

                Behavior on width {
                    NumberAnimation { duration: Tokens.motion.duration.short3 }
                }
                Behavior on color {
                    ColorAnimation { duration: Tokens.motion.duration.short3 }
                }
            }
        }
    }
}
