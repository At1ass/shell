pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.src.core.config
import qs.src.core.services
import qs.src.ui.feedback

// One dock entry: app icon, running-window indicator dots, hover scale, tooltip.
// Orientation-aware (horizontal row vs vertical column) — separator and dots flip,
// and the reported hover `center` is along the bar's main axis.
Item {
    id: root

    required property var app          // DockService.model item {key,appId,entry,windows,pinned,cls}
    required property int index
    property int iconSize: 48
    property int dockSpacing: 4
    property bool showSeparator: false
    property string position: "bottom"

    readonly property bool vertical: position === "left" || position === "right"

    // Hover reports the icon center along the main axis (window coords) for preview/tooltip.
    signal requestPreview(int index, real center)   // running app
    signal cancelPreview(int index, real center)     // non-running app (still wants a tooltip)
    signal hoverEnded(int index)
    signal requestContextMenu(var app, var iconRect)
    // Drag-to-reorder (pinned only): move from this index by `to - from` slots.
    signal requestReorder(int from, int to)

    readonly property bool isActive: app.windows.length > 0
    readonly property bool isFocused: {
        for (let i = 0; i < app.windows.length; i++) {
            if (app.windows[i].activated) return true
        }
        return false
    }
    readonly property bool isUrgent: {
        for (let i = 0; i < app.windows.length; i++) {
            if (app.windows[i].urgent) return true
        }
        return false
    }

    // Launch feedback: bounce while the app is starting (triggered for ANY launch source via
    // DockService.appLaunched). Cleared when a new window appears (running count grows past the
    // count at launch time) or after a timeout.
    property bool _launching: false
    property int _launchBaseCount: 0
    readonly property int runningCount: app.windows.length
    onRunningCountChanged: {
        if (_launching && runningCount > _launchBaseCount) {
            _launching = false
            launchTimer.stop()
        }
    }
    Timer { id: launchTimer; interval: 5000; onTriggered: root._launching = false }

    Connections {
        target: DockService
        function onAppLaunched(key) {
            if (key === root.app.key) {
                root._launchBaseCount = root.app.windows.length
                root._launching = true
                launchTimer.restart()
            }
        }
    }

    readonly property int _sepExtent: showSeparator ? (1 + dockSpacing) : 0
    implicitWidth: vertical ? (iconSize + 12) : (_sepExtent + iconButton.width)
    implicitHeight: vertical ? (_sepExtent + iconButton.height) : (iconSize + 12)
    Layout.alignment: Qt.AlignCenter

    // === Drag-to-reorder (pinned icons) ===
    // Visual follow during drag (a transform, so the layout is undisturbed); on release the
    // travel is converted to a slot delta and the pinned list is reordered.
    property real _dragOffset: 0
    readonly property int _slotExtent: (iconSize + 8) + dockSpacing

    z: dragHandler.active ? 10 : 0
    transform: Translate {
        x: root.vertical ? 0 : root._dragOffset
        y: root.vertical ? root._dragOffset : 0
    }
    Behavior on _dragOffset {
        enabled: !dragHandler.active
        NumberAnimation { duration: Tokens.motion.duration.short3 }
    }

    DragHandler {
        id: dragHandler
        enabled: root.app.pinned
        target: null
        onTranslationChanged: root._dragOffset = root.vertical ? translation.y : translation.x
        onActiveChanged: {
            if (!active) {
                const slot = Math.round(root._dragOffset / Math.max(1, root._slotExtent))
                if (slot !== 0) root.requestReorder(root.index, root.index + slot)
                root._dragOffset = 0
            }
        }
    }

    // Separator between pinned and running groups: vertical line (horizontal dock) at the
    // start edge, or horizontal line (vertical dock) at the top.
    Rectangle {
        id: separatorRect
        visible: root.showSeparator
        color: Qt.alpha(Theme.outline, 0.4)
        width: root.vertical ? root.iconSize * 0.6 : 1
        height: root.vertical ? 1 : root.iconSize * 0.6
        anchors.horizontalCenter: root.vertical ? parent.horizontalCenter : undefined
        anchors.verticalCenter: root.vertical ? undefined : parent.verticalCenter
        anchors.left: root.vertical ? undefined : parent.left
        anchors.top: root.vertical ? parent.top : undefined
    }

    Rectangle {
        id: iconButton
        width: root.iconSize + 8
        height: root.iconSize + 8
        anchors.horizontalCenter: root.vertical ? parent.horizontalCenter : undefined
        anchors.verticalCenter: root.vertical ? undefined : parent.verticalCenter
        anchors.right: root.vertical ? undefined : parent.right
        anchors.bottom: root.vertical ? parent.bottom : undefined
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

        // Urgency pulse (attention) behind the icon.
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Theme.tertiary
            visible: root.isUrgent
            opacity: 0
            SequentialAnimation on opacity {
                running: root.isUrgent
                loops: Animation.Infinite
                NumberAnimation { from: 0.0; to: 0.5; duration: 650; easing.type: Easing.InOutSine }
                NumberAnimation { from: 0.5; to: 0.0; duration: 650; easing.type: Easing.InOutSine }
            }
        }

        Image {
            id: iconImage
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

            // Launch bounce — pulses while the pinned app is starting up.
            SequentialAnimation on scale {
                running: root._launching
                loops: Animation.Infinite
                NumberAnimation {
                    from: 1.0; to: 1.18; duration: Tokens.motion.duration.medium2
                    easing.type: Tokens.motion.easing.emphasizedDecelerate
                    easing.bezierCurve: Tokens.motion.easing.emphasizedDeceleratePoints
                }
                NumberAnimation {
                    from: 1.18; to: 1.0; duration: Tokens.motion.duration.medium2
                    easing.type: Tokens.motion.easing.emphasizedAccelerate
                    easing.bezierCurve: Tokens.motion.easing.emphasizedAcceleratePoints
                }
                onRunningChanged: if (!running) iconImage.scale = 1.0
            }
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
                if (containsMouse) {
                    const p = iconButton.mapToItem(null, iconButton.width / 2, iconButton.height / 2)
                    const c = root.vertical ? p.y : p.x
                    if (root.isActive) root.requestPreview(root.index, c)
                    else root.cancelPreview(root.index, c)
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

    }

    // Running indicator dots — on the screen-edge side of the icon, laid out along the
    // bar's main axis (row for horizontal, column for vertical).
    Grid {
        anchors.horizontalCenter: root.vertical ? undefined : iconButton.horizontalCenter
        anchors.verticalCenter: root.vertical ? iconButton.verticalCenter : undefined
        anchors.top: root.position === "bottom" ? iconButton.bottom : undefined
        anchors.bottom: root.position === "top" ? iconButton.top : undefined
        anchors.left: root.position === "right" ? iconButton.right : undefined
        anchors.right: root.position === "left" ? iconButton.left : undefined
        anchors.margins: 1
        // Grid (positioner) wants a single positive dimension: 1 column (vertical dock)
        // or one row of up to N (horizontal). -1 is invalid here (unlike GridLayout).
        columns: root.vertical ? 1 : 99
        spacing: 3
        visible: root.isActive

        Repeater {
            model: Math.min(root.app.windows.length, 3)

            Rectangle {
                required property int index
                readonly property bool long: root.isFocused && index === 0
                width: root.vertical ? 4 : (long ? 10 : 4)
                height: root.vertical ? (long ? 10 : 4) : 4
                radius: 2
                color: root.isFocused ? Theme.primary : Theme.onSurfaceVariant

                Behavior on width {
                    NumberAnimation { duration: Tokens.motion.duration.short3 }
                }
                Behavior on height {
                    NumberAnimation { duration: Tokens.motion.duration.short3 }
                }
                Behavior on color {
                    ColorAnimation { duration: Tokens.motion.duration.short3 }
                }
            }
        }
    }
}
