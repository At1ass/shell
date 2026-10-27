pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.src.core.config
import qs.src.ui.base
import qs.src.ui.containers
import qs.src.ui.feedback

// Live window-preview card shown beside a hovered running app. Presentational —
// the coordinator (Dock) owns show/hide timing; this reports hover and dismissal.
// Orientation follows the dock: a horizontal dock lays thumbnails in a row (scrolls
// horizontally on overflow); a vertical dock lays them in a column (scrolls vertically).
// The card is clamped to the screen so it never overflows off-edge.
Surface {
    id: root

    property var model: []             // Wayland toplevels (DockService.toplevelsFor(...))
    property real center: 0            // along-axis center (x for horizontal, y for vertical)
    property bool showing: false
    property int thumbHeight: 180
    property string fallbackIcon: ""
    property Item anchorItem: null     // dock bar; preview sits on its inner side
    property string position: "bottom"

    readonly property bool vertical: position === "left" || position === "right"
    readonly property int _pad: Tokens.spacing.medium
    readonly property int _margin: Tokens.spacing.small
    readonly property int _gap: Tokens.spacing.extraSmall

    readonly property real _contentW: previewGrid.implicitWidth + _pad * 2
    readonly property real _contentH: previewGrid.implicitHeight + _pad * 2
    // Reserve the actual bar-side area, including its position and outer margin.
    readonly property real _maxW: {
        if (!parent) return 0
        if (!vertical || !anchorItem) return Math.max(0, parent.width - _margin * 2)
        return Math.max(0, position === "left"
            ? parent.width - anchorItem.x - anchorItem.width - _gap - _margin
            : anchorItem.x - _gap - _margin)
    }
    readonly property real _maxH: {
        if (!parent) return 0
        if (vertical || !anchorItem) return Math.max(0, parent.height - _margin * 2)
        return Math.max(0, position === "top"
            ? parent.height - anchorItem.y - anchorItem.height - _gap - _margin
            : anchorItem.y - _gap - _margin)
    }
    property real _animatedCenter: center
    Behavior on _animatedCenter {
        enabled: root.showing && root.visible
        MotionAnimation { duration: Tokens.motion.duration.short3; curve: "emphasized" }
    }

    signal hoverChanged(bool hovered)
    signal requestDismiss()

    visible: showing
    opacity: visible ? 1 : 0
    scale: visible ? 1 : 0.92
    transformOrigin: position === "bottom" ? Item.Bottom
                   : position === "top" ? Item.Top
                   : position === "left" ? Item.Left : Item.Right

    // Positioned entirely via x/y (no anchors) so all four sides share one path.
    x: {
        if (!anchorItem || !parent) return 0
        const target = vertical
            ? (position === "left" ? anchorItem.x + anchorItem.width + _gap : anchorItem.x - width - _gap)
            : Math.max(_margin, Math.min(_animatedCenter - width / 2, parent.width - width - _margin))
        return Math.max(0, Math.min(target, parent.width - width))
    }
    y: {
        if (!anchorItem || !parent) return 0
        const target = vertical
            ? Math.max(_margin, Math.min(_animatedCenter - height / 2, parent.height - height - _margin))
            : (position === "top" ? anchorItem.y + anchorItem.height + _gap : anchorItem.y - height - _gap)
        return Math.max(0, Math.min(target, parent.height - height))
    }

    width: Math.min(_contentW, _maxW)
    height: Math.min(_contentH, _maxH)

    elevation: 3                       // MD3: floating/overlay surface
    radius: Tokens.shape.large
    color: Qt.alpha(Theme.surfaceContainer, AppConfig.panelOpacity)
    clip: true

    // Surface tint (parent is Surface's content holder — use root.radius).
    SurfaceTint {
        level: 1
        radius: root.radius
    }

    Behavior on opacity {
        NumberAnimation { duration: Tokens.motion.duration.short4 }
    }
    Behavior on scale {
        MotionAnimation {
            duration: Tokens.motion.duration.medium1
            curve: "emphasizedDecelerate"
        }
    }
    HoverHandler {
        onHoveredChanged: root.hoverChanged(hovered)
    }

    Flickable {
        id: flick
        x: root._pad
        y: root._pad
        width: Math.max(0, root.width - root._pad * 2)
        height: Math.max(0, root.height - root._pad * 2)
        contentWidth: previewGrid.implicitWidth
        contentHeight: previewGrid.implicitHeight
        clip: true
        flickableDirection: root.vertical ? Flickable.VerticalFlick : Flickable.HorizontalFlick
        boundsBehavior: Flickable.StopAtBounds
        interactive: root.vertical ? (contentHeight > height) : (contentWidth > width)

        // Map wheel to scrolling along the overflow axis.
        WheelHandler {
            enabled: flick.interactive
            onWheel: (ev) => {
                const d = (ev.angleDelta.y !== 0 ? ev.angleDelta.y : ev.angleDelta.x)
                if (root.vertical)
                    flick.contentY = Math.max(0, Math.min(flick.contentY - d,
                                              flick.contentHeight - flick.height))
                else
                    flick.contentX = Math.max(0, Math.min(flick.contentX - d,
                                              flick.contentWidth - flick.width))
            }
        }

        // Row (horizontal dock) or column (vertical dock) of thumbnails.
        Grid {
            id: previewGrid
            // Single column (vertical dock) or single row (horizontal). -1 is invalid for
            // Grid (the positioner), unlike GridLayout.
            columns: root.vertical ? 1 : 99
            rowSpacing: Tokens.spacing.small
            columnSpacing: Tokens.spacing.small

            Repeater {
                // ScriptModel diffs by object identity, so delegates (and
                // their live ScreencopyViews) survive unrelated window events
                // instead of being torn down on every reconcile.
                model: ScriptModel { values: root.model }

                delegate: Item {
                    id: previewDelegate
                    required property var modelData
                    required property int index

                    readonly property bool isFocused: modelData.activated

                    width: thumbColumn.implicitWidth
                    height: thumbColumn.implicitHeight

                    Column {
                        id: thumbColumn
                        spacing: Tokens.spacing.extraSmall

                        MaterialShape {
                            id: thumbContainer
                            width: Math.max(0, Math.min(280, root._maxW - root._pad * 2))
                            height: Math.max(0, Math.min(root.thumbHeight, root._maxH - root._pad * 2 - windowTitle.implicitHeight - thumbColumn.spacing))
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
                                live: root.showing && root.visible && thumbContainer.height > 0
                                constraintSize: Qt.size(Math.max(1, Math.min(280, thumbContainer.width)), Math.max(1, thumbContainer.height - Tokens.spacing.extraSmall))
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
                            MaterialShape {
                                id: closeBtn
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.margins: Tokens.spacing.extraSmall
                                width: 24
                                height: 24
                                radius: Tokens.shape.full
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
                            id: windowTitle
                            objectName: "dockPreviewTitle"
                            width: thumbContainer.width
                            text: previewDelegate.modelData.title || "Untitled"
                            textFormat: Text.PlainText
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
}
