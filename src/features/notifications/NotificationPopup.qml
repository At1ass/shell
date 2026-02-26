import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.src.core.services
import qs.src.core.config

PanelWindow {
    id: popup

    required property var notificationData
    required property var notificationObject
    required property int screenY
    property bool exiting: false
    property bool _isDestroying: false
    property bool _finalized: false
    readonly property bool hasValidData: notificationData !== null

    signal exitFinished()

    visible: hasValidData && !_isDestroying
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "shell:notification-popup"
    exclusiveZone: 0
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors {
        top: true
        right: true
    }

    margins {
        top: screenY
        right: AppConfig.barMargin
    }

    implicitWidth: AppConfig.notificationPopupWidth
    implicitHeight: popupItem.implicitHeight

    // No mask — each window IS the notification, fully interactive by default

    // Smooth Y displacement when stack reorganizes
    Behavior on screenY {
        enabled: !popup.exiting && !popup._isDestroying
        NumberAnimation {
            duration: Tokens.motion.duration.short4
            easing.type: Tokens.motion.easing.standard
            easing.bezierCurve: Tokens.motion.easing.standardPoints
        }
    }

    // Entrance animation state
    property real _entranceX: AppConfig.notificationPopupWidth
    property real _entranceOpacity: 0

    ParallelAnimation {
        id: entranceAnim
        running: false
        NumberAnimation {
            target: popup; property: "_entranceX"; to: 0
            duration: Tokens.motion.duration.medium2
            easing.type: Tokens.motion.easing.standard
            easing.bezierCurve: Tokens.motion.easing.standardPoints
        }
        NumberAnimation {
            target: popup; property: "_entranceOpacity"; to: 1.0
            duration: Tokens.motion.duration.short4
        }
    }

    // Exit animation
    property real _exitScale: 1.0

    ParallelAnimation {
        id: exitAnim
        running: false
        NumberAnimation {
            target: popup; property: "_entranceX"
            to: AppConfig.notificationPopupWidth * 0.5
            duration: Tokens.motion.duration.short4
            easing.type: Tokens.motion.easing.emphasizedAccelerate
            easing.bezierCurve: Tokens.motion.easing.emphasizedAcceleratePoints
        }
        NumberAnimation {
            target: popup; property: "_entranceOpacity"
            to: 0
            duration: Tokens.motion.duration.short3
        }
        NumberAnimation {
            target: popup; property: "_exitScale"
            to: 0.95
            duration: Tokens.motion.duration.short4
            easing.type: Tokens.motion.easing.emphasizedAccelerate
            easing.bezierCurve: Tokens.motion.easing.emphasizedAcceleratePoints
        }
        onFinished: popup._finalizeExit()
    }

    // Watchdog: force-exit if animation hangs
    Timer {
        id: exitWatchdog
        interval: 600
        repeat: false
        onTriggered: {
            if (!popup._finalized) {
                popup._finalizeExit()
            }
        }
    }

    Component.onCompleted: entranceAnim.start()

    function startExit() {
        if (exiting || _isDestroying) return
        exiting = true
        exitAnim.start()
        exitWatchdog.start()
    }

    function forceExit() {
        if (_isDestroying) return
        _isDestroying = true
        exitAnim.stop()
        exitWatchdog.stop()
        visible = false
        _finalizeExit()
    }

    function _finalizeExit() {
        if (_finalized) return
        _finalized = true
        _isDestroying = true
        exitWatchdog.stop()
        exitFinished()
    }

    function updateData(newData) {
        notificationData = newData
        popupItem.updateData(newData)
    }

    NotificationPopupItem {
        id: popupItem
        notificationData: popup.notificationData
        duration: {
            const meta = NotificationService.activeNotifications[popup.notificationData?.notificationId]
            return meta ? meta.duration : 0
        }

        transform: [
            Translate { x: popup._entranceX },
            Scale {
                origin.x: popupItem.width / 2
                origin.y: popupItem.height / 2
                xScale: popup._exitScale
                yScale: popup._exitScale
            }
        ]
        opacity: popup._entranceOpacity

        onSwipeDismissed: {
            NotificationService.dismissActiveNotification(popup.notificationData.notificationId)
        }
        onCloseClicked: {
            NotificationService.dismissActiveNotification(popup.notificationData.notificationId)
        }
        onActionInvoked: (actionId) => {
            NotificationService.attemptInvokeAction(popup.notificationData.notificationId, actionId)
        }
        onTimeoutExpired: {
            NotificationService.dismissActiveNotification(popup.notificationData.notificationId)
        }
    }
}
