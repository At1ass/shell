pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.src.core.config
import qs.src.core.services

Scope {
    id: root

    // Selection state (shared across all screen overlays)
    property bool selecting: false
    property ShellScreen activeScreen: null
    property real startX: 0
    property real startY: 0
    property real endX: 0
    property real endY: 0

    readonly property real selX: Math.min(startX, endX)
    readonly property real selY: Math.min(startY, endY)
    readonly property real selW: Math.abs(endX - startX)
    readonly property real selH: Math.abs(endY - startY)

    function cancel() {
        GlobalStates.screenshotOverlayActive = false
        selecting = false
        activeScreen = null
    }

    function capture() {
        if (selW < 3 || selH < 3) {
            cancel()
            return
        }

        if (!activeScreen) {
            cancel()
            return
        }

        // grim uses compositor-space logical coordinates
        const gx = Math.round(activeScreen.x + selX)
        const gy = Math.round(activeScreen.y + selY)
        const gw = Math.round(selW)
        const gh = Math.round(selH)

        selecting = false
        activeScreen = null
        // Delegate to GlobalStates — it hides overlay first, then runs grim with delay
        GlobalStates.captureRegion(`${gx},${gy} ${gw}x${gh}`)
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: overlayWindow
            required property ShellScreen modelData
            screen: modelData

            visible: GlobalStates.screenshotOverlayActive
            color: "transparent"
            exclusiveZone: 0
            exclusionMode: ExclusionMode.Ignore
            focusable: true

            anchors {
                left: true
                right: true
                top: true
                bottom: true
            }

            WlrLayershell.namespace: "quickshell:screenshot"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            Item {
                id: content
                anchors.fill: parent
                focus: true

                property bool isActiveScreen: root.selecting && root.activeScreen === overlayWindow.modelData
                property real sx: isActiveScreen ? root.selX : 0
                property real sy: isActiveScreen ? root.selY : 0
                property real sw: isActiveScreen ? root.selW : 0
                property real sh: isActiveScreen ? root.selH : 0
                property bool hasSelection: isActiveScreen && sw > 0 && sh > 0

                // --- Dim overlay: 4 rectangles around selection ---

                // Top
                Rectangle {
                    x: 0; y: 0
                    width: parent.width
                    height: content.hasSelection ? Math.max(0, content.sy) : parent.height
                    color: "#50000000"
                }

                // Bottom
                Rectangle {
                    visible: content.hasSelection
                    x: 0
                    y: content.sy + content.sh
                    width: parent.width
                    height: Math.max(0, parent.height - content.sy - content.sh)
                    color: "#50000000"
                }

                // Left
                Rectangle {
                    visible: content.hasSelection
                    x: 0
                    y: content.sy
                    width: Math.max(0, content.sx)
                    height: content.sh
                    color: "#50000000"
                }

                // Right
                Rectangle {
                    visible: content.hasSelection
                    x: content.sx + content.sw
                    y: content.sy
                    width: Math.max(0, parent.width - content.sx - content.sw)
                    height: content.sh
                    color: "#50000000"
                }

                // Selection border
                Rectangle {
                    visible: content.hasSelection
                    x: content.sx
                    y: content.sy
                    width: content.sw
                    height: content.sh
                    color: "transparent"
                    border.color: Theme.primary
                    border.width: 2
                }

                // Dimensions label
                Rectangle {
                    visible: content.hasSelection && content.sw > 10 && content.sh > 10
                    x: content.sx + content.sw / 2 - width / 2
                    y: content.sy + content.sh + 8
                    width: dimText.implicitWidth + 16
                    height: dimText.implicitHeight + 8
                    radius: Tokens.shape.extraSmall
                    color: Theme.inverseSurface

                    Text {
                        id: dimText
                        anchors.centerIn: parent
                        text: `${Math.round(content.sw)} x ${Math.round(content.sh)}`
                        color: Theme.inverseOnSurface
                        font.pixelSize: Tokens.typography.labelSmall.size
                    }
                }

                // Crosshair cursor lines (when not yet selecting)
                Rectangle {
                    visible: mouseArea.containsMouse && !root.selecting
                    x: 0
                    y: mouseArea.mouseY
                    width: parent.width
                    height: 1
                    color: Qt.alpha(Theme.primary, 0.5)
                }
                Rectangle {
                    visible: mouseArea.containsMouse && !root.selecting
                    x: mouseArea.mouseX
                    y: 0
                    width: 1
                    height: parent.height
                    color: Qt.alpha(Theme.primary, 0.5)
                }

                MouseArea {
                    id: mouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.CrossCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton

                    onPressed: mouse => {
                        if (mouse.button === Qt.RightButton) {
                            root.cancel()
                            return
                        }
                        root.activeScreen = overlayWindow.modelData
                        root.startX = mouse.x
                        root.startY = mouse.y
                        root.endX = mouse.x
                        root.endY = mouse.y
                        root.selecting = true
                    }

                    onPositionChanged: mouse => {
                        if (root.selecting && root.activeScreen === overlayWindow.modelData) {
                            root.endX = Math.max(0, Math.min(mouse.x, content.width))
                            root.endY = Math.max(0, Math.min(mouse.y, content.height))
                        }
                    }

                    onReleased: mouse => {
                        if (mouse.button === Qt.LeftButton && root.selecting) {
                            root.capture()
                        }
                    }
                }

                Keys.onEscapePressed: root.cancel()
            }
        }
    }
}
