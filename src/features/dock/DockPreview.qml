pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Wayland
import qs.src.core.config
import qs.src.ui.base
import qs.src.ui.containers
import qs.src.ui.feedback

// Live window-preview card shown above a hovered running app. Presentational —
// the coordinator (Dock) owns show/hide timing; this reports hover and dismissal.
Surface {
    id: root

    property var model: []             // Wayland toplevels (DockService.toplevelsFor(...))
    property real centerX: 0           // window-coord center to align under
    property bool showing: false
    property int thumbHeight: 180
    property string fallbackIcon: ""
    property Item anchorItem: null     // dock bar; preview sits on its inner side
    property bool atTop: false         // dock at top → preview below the bar

    signal hoverChanged(bool hovered)
    signal requestDismiss()

    visible: showing
    opacity: visible ? 1 : 0
    scale: visible ? 1 : 0.92
    transformOrigin: atTop ? Item.Top : Item.Bottom

    anchors.top: (anchorItem && atTop) ? anchorItem.bottom : undefined
    anchors.bottom: (anchorItem && !atTop) ? anchorItem.top : undefined
    anchors.topMargin: atTop ? Tokens.spacing.extraSmall : 0
    anchors.bottomMargin: atTop ? 0 : Tokens.spacing.extraSmall

    x: {
        const margin = Tokens.spacing.small
        const targetX = centerX - width / 2
        return Math.max(margin, Math.min(targetX, parent.width - width - margin))
    }

    width: previewRow.implicitWidth + Tokens.spacing.medium * 2
    height: previewRow.implicitHeight + Tokens.spacing.medium * 2

    elevation: 3                       // MD3: floating/overlay surface
    radius: Tokens.shape.large
    color: Qt.alpha(Theme.surfaceContainer, 0.95)
    clip: true

    // Surface tint (parent is Surface's content holder — use root.radius).
    Rectangle {
        anchors.fill: parent
        color: Theme.primary
        opacity: 0.06
        radius: root.radius
    }

    Behavior on opacity {
        NumberAnimation { duration: Tokens.motion.duration.short4 }
    }
    Behavior on scale {
        NumberAnimation {
            duration: Tokens.motion.duration.medium1
            easing.type: Tokens.motion.easing.emphasizedDecelerate
            easing.bezierCurve: Tokens.motion.easing.emphasizedDeceleratePoints
        }
    }
    Behavior on x {
        NumberAnimation {
            duration: Tokens.motion.duration.short3
            easing.type: Tokens.motion.easing.emphasized
            easing.bezierCurve: Tokens.motion.easing.emphasizedPoints
        }
    }

    HoverHandler {
        onHoveredChanged: root.hoverChanged(hovered)
    }

    Row {
        id: previewRow
        anchors.centerIn: parent
        spacing: Tokens.spacing.small

        Repeater {
            model: root.model

            delegate: Item {
                id: previewDelegate
                required property var modelData
                required property int index

                readonly property bool isFocused: modelData.activated

                width: thumbColumn.implicitWidth
                height: thumbColumn.implicitHeight

                Column {
                    id: thumbColumn
                    spacing: 4

                    Rectangle {
                        id: thumbContainer
                        width: Math.max(screencopyView.implicitWidth > 0 ? screencopyView.implicitWidth : 280, 240)
                        height: root.thumbHeight
                        radius: Tokens.shape.small
                        color: previewDelegate.isFocused
                               ? Qt.alpha(Theme.primaryContainer, 0.5)
                               : Qt.alpha(Theme.surfaceContainerHighest, 0.5)
                        clip: true

                        border.width: previewDelegate.isFocused ? 2 : 0
                        border.color: Theme.primary

                        ScreencopyView {
                            id: screencopyView
                            anchors.centerIn: parent
                            captureSource: previewDelegate.modelData
                            live: true
                            constraintSize: Qt.size(280, root.thumbHeight - 4)
                            visible: hasContent
                        }

                        // Fallback when no content yet
                        Image {
                            anchors.centerIn: parent
                            width: 48
                            height: 48
                            visible: !screencopyView.hasContent
                            source: root.fallbackIcon ? "image://icon/" + root.fallbackIcon
                                                      : "image://icon/application-x-executable"
                            sourceSize: Qt.size(48, 48)
                            opacity: 0.5
                        }

                        StateLayer {
                            layerColor: Theme.onSurface
                            hovered: thumbMouse.containsMouse
                            pressed: thumbMouse.pressed
                        }

                        MouseArea {
                            id: thumbMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                previewDelegate.modelData.activate()
                                root.requestDismiss()
                            }
                        }

                        // Per-window close — window-level action lives where you see the
                        // window. Closes via the Wayland toplevel; the preview updates
                        // (and auto-hides when the last window closes).
                        Rectangle {
                            id: closeBtn
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: Tokens.spacing.extraSmall
                            width: 24
                            height: 24
                            radius: 12
                            z: 2
                            visible: thumbMouse.containsMouse || closeMouse.containsMouse
                            color: closeMouse.containsMouse
                                   ? Theme.errorContainer
                                   : Qt.alpha(Theme.surfaceContainerHighest, 0.92)

                            MaterialIcon {
                                anchors.centerIn: parent
                                iconName: "close"
                                fontSize: Tokens.iconSize.small
                                iconColor: closeMouse.containsMouse ? Theme.onErrorContainer : Theme.onSurface
                                backgroundColor: "transparent"
                            }

                            MouseArea {
                                id: closeMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: previewDelegate.modelData.close()
                            }
                        }
                    }

                    MaterialText {
                        width: thumbContainer.width
                        text: previewDelegate.modelData.title || "Untitled"
                        colorRole: "onSurface"
                        textStyle: "labelMedium"
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }
    }
}
