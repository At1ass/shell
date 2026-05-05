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

    // Position config
    readonly property string position: AppConfig.notificationPopupPosition
    readonly property bool isTop: position.startsWith("top")
    readonly property bool isRight: position.endsWith("right")

    signal exitFinished()

    visible: hasValidData && !_isDestroying
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "shell:notification-popup"
    exclusiveZone: 0
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors {
        top: popup.isTop
        bottom: !popup.isTop
        right: popup.isRight
        left: !popup.isRight
    }

    margins {
        top: popup.isTop ? screenY : 0
        bottom: !popup.isTop ? screenY : 0
        right: popup.isRight ? AppConfig.barMargin : 0
        left: !popup.isRight ? AppConfig.barMargin : 0
    }

    implicitWidth: AppConfig.notificationPopupWidth
    implicitHeight: popupItem.implicitHeight

    // Smooth Y displacement when stack reorganizes
    Behavior on screenY {
        enabled: !popup.exiting && !popup._isDestroying
        NumberAnimation {
            duration: Tokens.motion.duration.medium1
            easing.type: Tokens.motion.easing.emphasizedDecelerate
            easing.bezierCurve: Tokens.motion.easing.emphasizedDeceleratePoints
        }
    }

    // Entrance animation state — slide up/down + fade
    property real _entranceTranslateY: popup.isTop ? -40 : 40
    property real _entranceOpacity: 0
    property real _entranceScale: 0.92

    ParallelAnimation {
        id: entranceAnim
        running: false
        NumberAnimation {
            target: popup; property: "_entranceTranslateY"; to: 0
            duration: Tokens.motion.duration.medium2
            easing.type: Tokens.motion.easing.emphasizedDecelerate
            easing.bezierCurve: Tokens.motion.easing.emphasizedDeceleratePoints
        }
        NumberAnimation {
            target: popup; property: "_entranceOpacity"; to: 1.0
            duration: Tokens.motion.duration.medium1
            easing.type: Tokens.motion.easing.standard
        }
        NumberAnimation {
            target: popup; property: "_entranceScale"; to: 1.0
            duration: Tokens.motion.duration.medium2
            easing.type: Tokens.motion.easing.emphasizedDecelerate
            easing.bezierCurve: Tokens.motion.easing.emphasizedDeceleratePoints
        }
    }

    // Exit animation
    property real _exitScale: 1.0

    ParallelAnimation {
        id: exitAnim
        running: false
        NumberAnimation {
            target: popup; property: "_entranceTranslateY"
            to: popup.isTop ? -20 : 20
            duration: Tokens.motion.duration.short4
            easing.type: Tokens.motion.easing.emphasizedAccelerate
            easing.bezierCurve: Tokens.motion.easing.emphasizedAcceleratePoints
        }
        NumberAnimation {
            target: popup; property: "_entranceOpacity"
            to: 0
            duration: Tokens.motion.duration.short3
            easing.type: Tokens.motion.easing.emphasizedAccelerate
        }
        NumberAnimation {
            target: popup; property: "_exitScale"
            to: 0.92
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
            Translate { y: popup._entranceTranslateY },
            Scale {
                origin.x: popupItem.width / 2
                origin.y: popup.isTop ? 0 : popupItem.height
                xScale: popup._exitScale * popup._entranceScale
                yScale: popup._exitScale * popup._entranceScale
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
            NotificationService.expireActiveNotification(popup.notificationData.notificationId)
        }
    }
}
