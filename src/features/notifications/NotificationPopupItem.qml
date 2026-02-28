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

    // Decoupled signals
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
        interval: 33  // ~30fps
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
            // Restart with remaining time
            if (root.duration > 0 && _remainingOnPause > 0) {
                autoDismissTimer.interval = _remainingOnPause
                autoDismissTimer.restart()
            }
            NotificationService.decrementHover(notifId)
        }
    }

    // Swipe-to-dismiss state
    property real _dragStartX: 0
    property bool _swiping: false

    implicitWidth: AppConfig.notificationPopupWidth
    readonly property real nonAnimHeight: column.implicitHeight + Tokens.spacing.medium * 2
    implicitHeight: nonAnimHeight
    radius: Tokens.shape.extraSmall

    color: isCritical ? Theme.errorContainer : Theme.surfaceContainerHighest

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
        NumberAnimation {
            target: root; property: "x"
            to: root.implicitWidth; duration: Tokens.motion.duration.short3
            easing.type: Tokens.motion.easing.standard
            easing.bezierCurve: Tokens.motion.easing.standardPoints
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

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true

        onPressed: (mouse) => {
            root._dragStartX = mouse.x
            root._swiping = false
        }
        onPositionChanged: (mouse) => {
            if (!pressed) return
            const dx = mouse.x - root._dragStartX
            if (Math.abs(dx) > 10) root._swiping = true
            if (root._swiping) {
                root.x = Math.max(0, dx)
                root.opacity = 1.0 - (root.x / root.implicitWidth) * 0.5
            }
        }
        onReleased: (mouse) => {
            if (root._swiping && root.x > 70) {
                swipeDismissAnim.start()
            } else if (root._swiping) {
                root._swiping = false
                snapBackAnim.start()
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
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                fillMode: Image.PreserveAspectFit
                sourceSize.width: 48
                sourceSize.height: 48
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                MaterialText {
                    text: root.hasData ? (notificationData.appName || "") : ""
                    visible: text.length > 0
                    textStyle: "labelSmall"
                    font.weight: Font.Bold
                    color: isCritical ? Theme.onErrorContainer : Theme.onSurface
                }

                MaterialText {
                    text: root.hasData ? (notificationData.summary || "") : ""
                    textStyle: "bodyMedium"
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                    color: isCritical ? Theme.onErrorContainer : Theme.onSurface
                }
            }

            IconButton {
                iconName: "close"
                iconSize: Tokens.typography.titleMedium.size
                iconColor: isCritical ? Theme.onErrorContainer : Theme.onSurfaceVariant
                containerSize: 32
                touchTargetSize: 40
                variant: "standard"
                onClicked: root.closeClicked()
            }
        }

        MaterialText {
            text: root.hasData ? (notificationData.body || "") : ""
            visible: text.length > 0
            textStyle: "bodySmall"
            wrapMode: Text.WordWrap
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

        Repeater {
            model: root.hasData ? (notificationData.actions || []) : []

            MaterialButton {
                required property var modelData
                text: modelData.text
                variant: "text"
                onClicked: root.actionInvoked(modelData.identifier)
            }
        }
    }

    // Progress bar
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 2
        color: Theme.surfaceContainerHighest
        opacity: 0.6
        visible: root.duration > 0

        Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            height: parent.height
            width: parent.width * Math.max(0, Math.min(1, root.progressValue))
            color: Theme.primary

            Behavior on width {
                NumberAnimation {
                    duration: Tokens.motion.duration.short4
                    easing.type: Tokens.motion.easing.standard
                    easing.bezierCurve: Tokens.motion.easing.standardPoints
                }
            }
        }
    }

    function updateData(newData) {
        notificationData = newData
        // Reset timer on update
        _startTime = Date.now()
        _pausedDuration = 0
        progressValue = 1.0
        if (duration > 0) {
            autoDismissTimer.interval = duration
            autoDismissTimer.restart()
        }
    }
}
