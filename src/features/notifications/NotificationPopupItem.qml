pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import qs.src.core.services
import qs.src.core.config
import qs.src.ui.containers
import qs.src.ui.base
import qs.src.ui.feedback

Rectangle {
    id: root

    required property var notificationData
    property int duration: 0

    readonly property bool hasData: notificationData !== null && notificationData !== undefined
    readonly property bool isCritical: hasData && root.notificationData.urgency === NotificationUrgency.Critical
    readonly property bool hovered: mouseArea.containsMouse

    // Per freedesktop spec, the action with identifier "default" is the
    // implicit click target on the notification body — it's never meant
    // to be a labelled button. Filter it (and any empty-label actions)
    // out of the buttons strip; surface it via body click instead.
    readonly property var _allActions: hasData ? (root.notificationData.actions || []) : []
    readonly property var _visibleActions: _allActions.filter(
        a => a.identifier !== "default" && (a.text || "").trim().length > 0)
    readonly property var _defaultAction: _allActions.find(a => a.identifier === "default") ?? null

    signal swipeDismissed()
    signal closeClicked()
    signal actionInvoked(string actionId)
    signal timeoutExpired()

    // One timeline drives BOTH the progress bar and the auto-dismiss:
    // pausing on hover freezes them together, so the countdown and the bar
    // can never disagree (the previous wall-clock bookkeeping could stall a
    // popup forever after repeated hovers).
    property real progressValue: 1.0

    NumberAnimation {
        id: dismissAnim
        target: root
        property: "progressValue"
        from: 1.0
        to: 0.0
        // clamped: durationMs uses -1 as the "persistent, never expires"
        // sentinel (expireTimeout === 0 per spec). `running` below already
        // keeps the animation off for it, but assigning a negative duration
        // is still invalid and Qt warns on every such notification.
        duration: Math.max(0, root.duration)
        running: root.duration > 0 && root.visible
        paused: running && root.hovered
        onFinished: root.timeoutExpired()
    }



    // Swipe-to-dismiss state. _dragStartX and the deltas below are kept in
    // scene (window) coordinates via mapToItem(null, ...). Local MouseArea
    // coordinates are unstable here because root.x mutates during drag,
    // which translates the MouseArea and feeds back into mouse.x.
    property real _dragStartX: 0
    property real _dragInitialRootX: 0
    property bool _swiping: false
    property real _swipeDirection: 0

    implicitWidth: AppConfig.notificationPopupWidth
    readonly property real nonAnimHeight: column.implicitHeight + Tokens.spacing.medium * 2
    implicitHeight: nonAnimHeight
    radius: Tokens.shape.medium

    color: root.isCritical ? Theme.errorContainer : Theme.surfaceContainerHigh

    border.width: root.isCritical ? 2 : 0
    border.color: root.isCritical ? Theme.error : "transparent"

    // Snap-back animation for cancelled swipe
    ParallelAnimation {
        id: snapBackAnim
        MotionAnimation {
            target: root; property: "x"; to: 0
            duration: Tokens.motion.duration.short4
            curve: "standard"
        }
        NumberAnimation {
            target: root; property: "opacity"; to: 1.0
            duration: Tokens.motion.duration.short3
        }
    }

    // Swipe dismiss animation
    SequentialAnimation {
        id: swipeDismissAnim
        property real targetX: root.implicitWidth
        MotionAnimation {
            target: root; property: "x"
            to: swipeDismissAnim.targetX
            duration: Tokens.motion.duration.short3
            curve: "emphasizedAccelerate"
        }
        NumberAnimation {
            target: root; property: "opacity"
            to: 0; duration: Tokens.motion.duration.short1
        }
        ScriptAction {
            script: {
                root._swiping = false
                root.swipeDismissed()
            }
        }
    }

    // MD3 surface tint elevation. Was a hand-rolled Rectangle carrying
    // `Tokens.stateLayer.hoverOpacity` — a STATE-layer token used as a constant
    // elevation tint, so a popup at rest was painted as if hovered. SurfaceTint
    // has its own tintOpacity scale, which is what this needs.
    SurfaceTint {
        level: 3
        radius: root.radius
    }

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        border.color: Theme.outlineVariant
        border.width: 1
        color: "transparent"
    }

    // Critical urgency pulse overlay
    Rectangle {
        id: criticalPulse
        anchors.fill: parent
        radius: parent.radius
        color: Theme.error
        opacity: 0
        visible: root.isCritical

        SequentialAnimation {
            running: root.isCritical
            loops: 3
            MotionAnimation {
                target: criticalPulse; property: "opacity"
                from: 0; to: 0.12
                duration: Tokens.motion.duration.medium2
                curve: "standard"
            }
            MotionAnimation {
                target: criticalPulse; property: "opacity"
                from: 0.12; to: 0
                duration: Tokens.motion.duration.medium2
                curve: "standard"
            }
        }
    }

    // Hover state layer
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: root.isCritical ? Theme.onErrorContainer : Theme.onSurface
        opacity: root.hovered ? Tokens.stateLayer.hoverOpacity : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Tokens.motion.duration.short3
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true

        onPressed: (mouse) => {
            const scene = mouseArea.mapToItem(null, mouse.x, mouse.y)
            root._dragStartX = scene.x
            root._dragInitialRootX = root.x
            root._swiping = false
            root._swipeDirection = 0
        }
        onPositionChanged: (mouse) => {
            if (!pressed) return
            const scene = mouseArea.mapToItem(null, mouse.x, mouse.y)
            const dx = scene.x - root._dragStartX
            if (Math.abs(dx) > 10) {
                root._swiping = true
                root._swipeDirection = dx > 0 ? 1 : -1
            }
            if (root._swiping) {
                root.x = root._dragInitialRootX + dx
                root.opacity = 1.0 - (Math.abs(root.x) / root.implicitWidth) * 0.5
            }
        }
        onReleased: (mouse) => {
            if (root._swiping && Math.abs(root.x) > 50) {
                swipeDismissAnim.targetX = root._swipeDirection > 0 ? root.implicitWidth : -root.implicitWidth
                swipeDismissAnim.start()
            } else if (root._swiping) {
                root._swiping = false
                snapBackAnim.start()
            } else if (root._defaultAction) {
                // Plain click on the body invokes the implicit "default" action.
                root.actionInvoked(root._defaultAction.identifier)
            }
        }
    }

    ColumnLayout {
        id: column
        anchors.fill: parent
        anchors.margins: Tokens.spacing.medium
        spacing: Tokens.spacing.small

        RowLayout {
            spacing: Tokens.spacing.small
            Layout.fillWidth: true

            Image {
                visible: root.hasData && source !== ""
                source: root.hasData && root.notificationData.appIcon
                        ? Quickshell.iconPath(root.notificationData.appIcon)
                        : ""
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
                fillMode: Image.PreserveAspectFit
                sourceSize.width: 24
                sourceSize.height: 24
                smooth: true
            }

            MaterialText {
                text: root.hasData ? (root.notificationData.appName || "") : ""
                visible: text.length > 0
                textStyle: "labelMedium"
                font.weight: Font.Bold
                color: root.isCritical ? Theme.onErrorContainer : Theme.onSurfaceVariant
                elide: Text.ElideRight
                Layout.fillWidth: true
                Layout.minimumWidth: 0
            }

            // Repeat counter. Identical notifications merge into this card
            // instead of replacing it, so a second "New message" reads as "×2"
            // and nothing is lost — the old behaviour silently expired the
            // previous popup and the count of events disappeared with it.
            Rectangle {
                readonly property int repeatCount: root.hasData ? (root.notificationData.count ?? 1) : 1
                visible: repeatCount > 1
                implicitWidth: Math.max(countLabel.implicitWidth + Tokens.spacing.small, implicitHeight)
                implicitHeight: countLabel.implicitHeight + Tokens.spacing.extraSmall
                radius: Tokens.shape.full
                color: root.isCritical ? Theme.onErrorContainer : Theme.secondaryContainer

                MaterialText {
                    id: countLabel
                    anchors.centerIn: parent
                    text: "×" + parent.repeatCount
                    textStyle: "labelSmall"
                    color: root.isCritical ? Theme.errorContainer : Theme.onSecondaryContainer
                }
            }

            IconButton {
                iconName: "close"
                iconSize: Tokens.iconSize.small
                iconColor: root.isCritical ? Theme.onErrorContainer : Theme.onSurfaceVariant
                containerSize: 28
                touchTargetSize: 32
                variant: "standard"
                onClicked: root.closeClicked()
            }
        }

        MaterialText {
            text: root.hasData ? (root.notificationData.summary || "") : ""
            visible: text.length > 0
            textStyle: "titleSmall"
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
            Layout.fillWidth: true
            color: root.isCritical ? Theme.onErrorContainer : Theme.onSurface
        }

        MaterialText {
            text: root.hasData ? (root.notificationData.body || "") : ""
            visible: text.length > 0
            textStyle: "bodyMedium"
            textFormat: Text.StyledText
            wrapMode: Text.WordWrap
            maximumLineCount: 4
            elide: Text.ElideRight
            Layout.fillWidth: true
            color: root.isCritical ? Theme.onErrorContainer : Theme.onSurfaceVariant
        }

        // Notification image
        Rectangle {
            visible: root.hasData && (root.notificationData.image || "") !== ""
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? Math.min(notifImage.implicitHeight, 180) : 0
            radius: Tokens.shape.small
            clip: true
            color: "transparent"

            Image {
                id: notifImage
                anchors.fill: parent
                source: root.hasData ? (root.notificationData.image || "") : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                sourceSize.width: parent.width
            }
        }

        // Action buttons — horizontal flow. "default" identifier and
        // empty-label actions are excluded (handled via body click).
        Flow {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small
            visible: root._visibleActions.length > 0

            Repeater {
                model: root._visibleActions

                MaterialButton {
                    required property var modelData
                    text: modelData.text
                    variant: "tonal"
                    onClicked: root.actionInvoked(modelData.identifier)
                }
            }
        }
    }

    // Progress bar — inset to respect rounded corners.
    // ProgressIndicator from the kit; `animateValue: false` because
    // progressValue is already driven by the running countdown animation, and a
    // second Behavior on top of it would lag behind and smear the bar.
    ProgressIndicator {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: root.radius
        anchors.rightMargin: root.radius
        anchors.bottomMargin: 4
        visible: root.duration > 0
        opacity: root.hovered ? 0.5 : 1.0

        type: "linear"
        thickness: 3
        animateValue: false
        value: root.progressValue
        activeColor: root.isCritical ? Theme.error : Theme.primary
        trackColor: Qt.alpha(root.isCritical ? Theme.error : Theme.surfaceContainerHighest, 0.4)

        Behavior on opacity {
            NumberAnimation {
                duration: Tokens.motion.duration.short3
            }
        }
    }

    function updateData(newData) {
        notificationData = newData
        // Replaced content restarts the countdown; duration 0 = persistent
        // popup (restarting a zero-length animation would finish instantly
        // and dismiss it).
        if (duration > 0) dismissAnim.restart()
    }
}
