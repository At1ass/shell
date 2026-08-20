import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.src.core.services
import qs.src.core.config
import qs.src.ui.base

PanelWindow {
    id: popup

    // Server-side Notification.id. Mutable: a duplicate merge re-keys this
    // popup onto the newer notification rather than swapping cards.
    property int notifId: 0
    required property var notificationData
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
        MotionAnimation {
            duration: Tokens.motion.duration.medium1
            curve: "emphasizedDecelerate"
        }
    }

    // Entrance animation state — slide up/down + fade
    property real _entranceTranslateY: popup.isTop ? -40 : 40
    property real _entranceOpacity: 0
    property real _entranceScale: 0.92

    ParallelAnimation {
        id: entranceAnim
        running: false
        MotionAnimation {
            target: popup; property: "_entranceTranslateY"; to: 0
            duration: Tokens.motion.duration.medium2
            curve: "emphasizedDecelerate"
        }
        MotionAnimation {
            target: popup; property: "_entranceOpacity"; to: 1.0
            duration: Tokens.motion.duration.medium1
            curve: "standard"
        }
        MotionAnimation {
            target: popup; property: "_entranceScale"; to: 1.0
            duration: Tokens.motion.duration.medium2
            curve: "emphasizedDecelerate"
        }
    }

    // Exit animation
    property real _exitScale: 1.0

    ParallelAnimation {
        id: exitAnim
        running: false
        MotionAnimation {
            target: popup; property: "_entranceTranslateY"
            to: popup.isTop ? -20 : 20
            duration: Tokens.motion.duration.short4
            curve: "emphasizedAccelerate"
        }
        MotionAnimation {
            target: popup; property: "_entranceOpacity"
            to: 0
            duration: Tokens.motion.duration.short3
            curve: "emphasizedAccelerate"
        }
        MotionAnimation {
            target: popup; property: "_exitScale"
            to: 0.92
            duration: Tokens.motion.duration.short4
            curve: "emphasizedAccelerate"
        }
        onFinished: popup._finalizeExit()
    }

    Component.onCompleted: entranceAnim.start()

    function startExit() {
        if (exiting || _isDestroying) return
        exiting = true
        exitAnim.start()
    }

    function _finalizeExit() {
        if (_finalized) return
        _finalized = true
        _isDestroying = true
        exitFinished()
    }

    function updateData(newData) {
        notificationData = newData
        popupItem.updateData(newData)
    }

    NotificationPopupItem {
        id: popupItem
        notificationData: popup.notificationData
        duration: NotificationService.activeDuration(popup.notifId)

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

        // User intent only — the service decides what closing means and
        // whether the notification survives (a `resident` one does).
        onSwipeDismissed: NotificationService.dismissPopup(popup.notifId)
        onCloseClicked:   NotificationService.dismissPopup(popup.notifId)
        onActionInvoked:  (actionId) => NotificationService.invokeAction(popup.notifId, actionId)
        onTimeoutExpired: NotificationService.expirePopup(popup.notifId)
    }
}
