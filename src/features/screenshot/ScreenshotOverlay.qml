pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.src.core.config
import qs.src.core.services
import qs.src.ui.base

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

    // Keyboard navigation state
    property bool keyboardMode: false
    property bool anchorPlaced: false
    property real cursorX: 0
    property real cursorY: 0
    readonly property int kbStepSmall: 4
    readonly property int kbStepRepeat: 16
    readonly property int kbStepLarge: 40

    function cancel() {
        ScreenshotService.screenshotOverlayActive = false
        selecting = false
        activeScreen = null
        keyboardMode = false
        anchorPlaced = false
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
        keyboardMode = false
        anchorPlaced = false
        ScreenshotService.captureRegion(`${gx},${gy} ${gw}x${gh}`)
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: overlayWindow
            required property ShellScreen modelData
            screen: modelData

            visible: ScreenshotService.screenshotOverlayActive
            color: "transparent"
            exclusiveZone: -1
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
                    color: Qt.alpha(Theme.scrim, 0.31)
                }

                // Bottom
                Rectangle {
                    visible: content.hasSelection
                    x: 0
                    y: content.sy + content.sh
                    width: parent.width
                    height: Math.max(0, parent.height - content.sy - content.sh)
                    color: Qt.alpha(Theme.scrim, 0.31)
                }

                // Left
                Rectangle {
                    visible: content.hasSelection
                    x: 0
                    y: content.sy
                    width: Math.max(0, content.sx)
                    height: content.sh
                    color: Qt.alpha(Theme.scrim, 0.31)
                }

                // Right
                Rectangle {
                    visible: content.hasSelection
                    x: content.sx + content.sw
                    y: content.sy
                    width: Math.max(0, parent.width - content.sx - content.sw)
                    height: content.sh
                    color: Qt.alpha(Theme.scrim, 0.31)
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

                    MaterialText {
                        id: dimText
                        anchors.centerIn: parent
                        text: `${Math.round(content.sw)} x ${Math.round(content.sh)}`
                        textStyle: "labelSmall"
                        colorRole: "inverseOnSurface"
                    }
                }

                // Mouse crosshair (when hovering without selecting)
                Rectangle {
                    visible: mouseArea.containsMouse && !root.selecting && !root.keyboardMode
                    x: 0
                    y: mouseArea.mouseY
                    width: parent.width
                    height: 1
                    color: Qt.alpha(Theme.primary, 0.5)
                }
                Rectangle {
                    visible: mouseArea.containsMouse && !root.selecting && !root.keyboardMode
                    x: mouseArea.mouseX
                    y: 0
                    width: 1
                    height: parent.height
                    color: Qt.alpha(Theme.primary, 0.5)
                }

                // --- Keyboard crosshair ---
                Rectangle {
                    visible: root.keyboardMode && root.activeScreen === overlayWindow.modelData
                    x: 0
                    y: root.cursorY
                    width: parent.width
                    height: 1
                    color: Qt.alpha(Theme.tertiary, 0.9)
                }
                Rectangle {
                    visible: root.keyboardMode && root.activeScreen === overlayWindow.modelData
                    x: root.cursorX
                    y: 0
                    width: 1
                    height: parent.height
                    color: Qt.alpha(Theme.tertiary, 0.9)
                }

                // Anchor marker dot
                Rectangle {
                    visible: root.anchorPlaced && root.activeScreen === overlayWindow.modelData
                    x: root.startX - 4
                    y: root.startY - 4
                    width: 8
                    height: 8
                    radius: 4
                    color: Theme.tertiary
                }

                // Keyboard mode hint
                Rectangle {
                    visible: root.keyboardMode && root.activeScreen === overlayWindow.modelData
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottomMargin: 24
                    width: hintText.implicitWidth + 24
                    height: hintText.implicitHeight + 12
                    radius: Tokens.shape.full
                    color: Theme.inverseSurface
                    opacity: 0.85

                    MaterialText {
                        id: hintText
                        anchors.centerIn: parent
                        text: root.anchorPlaced
                              ? "h/j/k/l · Space or Enter: capture · Esc: cancel"
                              : "h/j/k/l · Space: place anchor · Esc: cancel"
                        textStyle: "labelSmall"
                        colorRole: "inverseOnSurface"
                    }
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
                        // Mouse takes over from keyboard mode
                        root.keyboardMode = false
                        root.anchorPlaced = false
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

                Keys.onPressed: event => {
                    const shift = !!(event.modifiers & Qt.ShiftModifier)
                    const step = shift ? root.kbStepLarge
                                      : event.isAutoRepeat ? root.kbStepRepeat
                                      : root.kbStepSmall

                    // Normalize hjkl to Qt key codes using XKB scan codes so
                    // navigation works regardless of the active keyboard layout.
                    // Qt Wayland stores nativeScanCode as XKB keycode = evdev + 8.
                    // h=43, j=44, k=45, l=46 on all standard keyboards.
                    let key = event.key
                    switch (event.nativeScanCode) {
                        case 43: key = Qt.Key_H; break
                        case 44: key = Qt.Key_J; break
                        case 45: key = Qt.Key_K; break
                        case 46: key = Qt.Key_L; break
                    }

                    function initKeyboard() {
                        if (!root.keyboardMode) {
                            // Find the screen that was focused when the screenshot
                            // was triggered, captured before the overlay stole focus.
                            const targetName = ScreenshotService.screenshotTargetMonitor
                            let targetScreen = null
                            for (let i = 0; i < Quickshell.screens.length; i++) {
                                if (Quickshell.screens[i].name === targetName) {
                                    targetScreen = Quickshell.screens[i]
                                    break
                                }
                            }
                            root.activeScreen = targetScreen || overlayWindow.modelData
                            root.cursorX = root.activeScreen.width / 2
                            root.cursorY = root.activeScreen.height / 2
                            root.keyboardMode = true
                        }
                    }

                    function updateSelection() {
                        if (root.anchorPlaced) {
                            root.endX = root.cursorX
                            root.endY = root.cursorY
                        }
                    }

                    // Bounds use the active screen's dimensions (set by initKeyboard).
                    // Key events arrive at one window only; the activeScreen check is
                    // not needed for movement — only the per-screen visuals use it.
                    switch (key) {
                    case Qt.Key_Escape:
                        root.cancel()
                        event.accepted = true
                        break

                    case Qt.Key_H: case Qt.Key_Left:
                        initKeyboard()
                        root.cursorX = Math.max(0, root.cursorX - step)
                        updateSelection()
                        event.accepted = true
                        break

                    case Qt.Key_L: case Qt.Key_Right:
                        initKeyboard()
                        root.cursorX = Math.min(root.activeScreen.width - 1, root.cursorX + step)
                        updateSelection()
                        event.accepted = true
                        break

                    case Qt.Key_K: case Qt.Key_Up:
                        initKeyboard()
                        root.cursorY = Math.max(0, root.cursorY - step)
                        updateSelection()
                        event.accepted = true
                        break

                    case Qt.Key_J: case Qt.Key_Down:
                        initKeyboard()
                        root.cursorY = Math.min(root.activeScreen.height - 1, root.cursorY + step)
                        updateSelection()
                        event.accepted = true
                        break

                    case Qt.Key_Space:
                        if (root.keyboardMode) {
                            if (!root.anchorPlaced) {
                                root.anchorPlaced = true
                                root.startX = root.cursorX
                                root.startY = root.cursorY
                                root.endX = root.cursorX
                                root.endY = root.cursorY
                                root.selecting = true
                            } else {
                                root.capture()
                            }
                        }
                        event.accepted = true
                        break

                    case Qt.Key_Return: case Qt.Key_Enter:
                        if (root.anchorPlaced)
                            root.capture()
                        event.accepted = true
                        break
                    }
                }
            }
        }
    }
}
