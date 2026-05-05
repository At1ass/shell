import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import qs.src.core.services
import qs.src.core.config
import qs.src.ui.base
import qs.src.ui.feedback

Rectangle {
    id: root

    required property var notificationData
    property int duration: 0
    property string notifId: notificationData?.notificationId ?? ""

    readonly property bool hasData: notificationData !== null && notificationData !== undefined
    readonly property bool isCritical: hasData && notificationData.urgency === NotificationUrgency.Critical
    readonly property bool hovered: mouseArea.containsMouse

    // Per freedesktop spec, the action with identifier "default" is the
    // implicit click target on the notification body — it's never meant
    // to be a labelled button. Filter it (and any empty-label actions)
    // out of the buttons strip; surface it via body click instead.
    readonly property var _allActions: hasData ? (notificationData.actions || []) : []
    readonly property var _visibleActions: _allActions.filter(
        a => a.identifier !== "default" && (a.text || "").trim().length > 0)
    readonly property var _defaultAction: _allActions.find(a => a.identifier === "default") ?? null

    signal swipeDismissed()
    signal closeClicked()
    signal actionInvoked(string actionId)
    signal timeoutExpired()

    // Local progress tracking
    property real _startTime: Date.now()
    property real _pausedDuration: 0
    property real _pauseStart: 0
    property real progressValue: 1.0

    Timer {
        interval: 33
        repeat: true
        running: root.duration > 0 && !root.hovered && root.visible
        onTriggered: {
            const elapsed = Date.now() - root._startTime - root._pausedDuration
            root.progressValue = Math.max(0, 1.0 - elapsed / root.duration)
        }
    }

    // Per-popup auto-dismiss timer
    property real _remainingOnPause: 0

    Timer {
        id: autoDismissTimer
        interval: root.duration > 0 ? root.duration : 0
        repeat: false
        running: root.duration > 0 && !root.hovered
        onTriggered: root.timeoutExpired()
    }

    onHoveredChanged: {
        if (hovered) {
            _pauseStart = Date.now()
            _remainingOnPause = Math.max(0, autoDismissTimer.interval - (Date.now() - _startTime - _pausedDuration))
            autoDismissTimer.stop()
            NotificationService.incrementHover(notifId)
        } else {
            _pausedDuration += Date.now() - _pauseStart
            if (root.duration > 0 && _remainingOnPause > 0) {
                autoDismissTimer.interval = _remainingOnPause
                autoDismissTimer.restart()
            }
            NotificationService.decrementHover(notifId)
        }
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

    color: isCritical ? Theme.errorContainer : Theme.surfaceContainerHigh

    border.width: isCritical ? 2 : 0
    border.color: isCritical ? Theme.error : "transparent"

    // Snap-back animation for cancelled swipe
    ParallelAnimation {
        id: snapBackAnim
        NumberAnimation {
            target: root; property: "x"; to: 0
            duration: Tokens.motion.duration.short4
            easing.type: Tokens.motion.easing.standard
            easing.bezierCurve: Tokens.motion.easing.standardPoints
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
        NumberAnimation {
            target: root; property: "x"
            to: swipeDismissAnim.targetX
            duration: Tokens.motion.duration.short3
            easing.type: Tokens.motion.easing.emphasizedAccelerate
            easing.bezierCurve: Tokens.motion.easing.emphasizedAcceleratePoints
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

    // MD3 surface tint elevation
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: Theme.primary
        opacity: Tokens.stateLayer.hoverOpacity
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
        visible: isCritical

        SequentialAnimation {
            running: isCritical
            loops: 3
            NumberAnimation {
                target: criticalPulse; property: "opacity"
                from: 0; to: 0.12
                duration: Tokens.motion.duration.medium2
                easing.type: Easing.InOutQuad
            }
            NumberAnimation {
                target: criticalPulse; property: "opacity"
                from: 0.12; to: 0
                duration: Tokens.motion.duration.medium2
                easing.type: Easing.InOutQuad
            }
        }
    }

    // Hover state layer
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: isCritical ? Theme.onErrorContainer : Theme.onSurface
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
                source: root.hasData && notificationData.appIcon
                        ? Quickshell.iconPath(notificationData.appIcon)
                        : ""
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
                fillMode: Image.PreserveAspectFit
                sourceSize.width: 24
                sourceSize.height: 24
                smooth: true
            }

            MaterialText {
                text: root.hasData ? (notificationData.appName || "") : ""
                visible: text.length > 0
                textStyle: "labelMedium"
                font.weight: Font.Bold
                color: isCritical ? Theme.onErrorContainer : Theme.onSurfaceVariant
                elide: Text.ElideRight
                Layout.fillWidth: true
                Layout.minimumWidth: 0
            }

            IconButton {
                iconName: "close"
                iconSize: Tokens.iconSize.small
                iconColor: isCritical ? Theme.onErrorContainer : Theme.onSurfaceVariant
                containerSize: 28
                touchTargetSize: 32
                variant: "standard"
                onClicked: root.closeClicked()
            }
        }

        MaterialText {
            text: root.hasData ? (notificationData.summary || "") : ""
            visible: text.length > 0
            textStyle: "titleSmall"
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
            Layout.fillWidth: true
            color: isCritical ? Theme.onErrorContainer : Theme.onSurface
        }

        MaterialText {
            text: root.hasData ? (notificationData.body || "") : ""
            visible: text.length > 0
            textStyle: "bodyMedium"
            textFormat: Text.StyledText
            wrapMode: Text.WordWrap
            maximumLineCount: 4
            elide: Text.ElideRight
            Layout.fillWidth: true
            color: isCritical ? Theme.onErrorContainer : Theme.onSurfaceVariant
        }

        // Notification image
        Rectangle {
            visible: root.hasData && (notificationData.image || "") !== ""
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? Math.min(notifImage.implicitHeight, 180) : 0
            radius: Tokens.shape.small
            clip: true
            color: "transparent"

            Image {
                id: notifImage
                anchors.fill: parent
                source: root.hasData ? (notificationData.image || "") : ""
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

    // Progress bar — inset to respect rounded corners
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: root.radius
        anchors.rightMargin: root.radius
        anchors.bottomMargin: 4
        height: 3
        radius: 2
        color: isCritical ? Theme.error : Theme.surfaceContainerHighest
        opacity: 0.4
        visible: root.duration > 0

        Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            height: parent.height
            radius: parent.radius
            width: parent.width * Math.max(0, Math.min(1, root.progressValue))
            color: isCritical ? Theme.error : Theme.primary
            opacity: root.hovered ? 0.5 : 1.0

            Behavior on opacity {
                NumberAnimation {
                    duration: Tokens.motion.duration.short3
                }
            }

            Behavior on width {
                NumberAnimation {
                    duration: 50
                    easing.type: Easing.Linear
                }
            }
        }
    }

    function updateData(newData) {
        notificationData = newData
        _startTime = Date.now()
        _pausedDuration = 0
        progressValue = 1.0
        if (duration > 0) {
            autoDismissTimer.interval = duration
            autoDismissTimer.restart()
        }
    }
}
