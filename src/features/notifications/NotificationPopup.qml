import QtQuick
import qs.src.core.services
import qs.src.core.config
import qs.src.ui.base

// ONE CARD in the stack, not a window. This used to be a PanelWindow of its
// own, positioned by `margins.top`, and the stack slide animated that margin —
// a layer-shell reconfigure per frame. It now lives inside
// NotificationPopupSurface (one surface per screen) and slides by animating
// `y`, which never leaves the client. See that file for the measurement.
Item {
    id: popup

    // Server-side Notification.id. Mutable: a duplicate merge re-keys this
    // popup onto the newer notification rather than swapping cards.
    property int notifId: 0
    // Which screen's stack this card belongs to. The card is no longer a
    // window, so it cannot be asked for its output.
    property string screenName: ""
    required property var notificationData
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

    // Offset within the surface, set by the manager. Purely client-side now.
    anchors.left: parent ? parent.left : undefined
    anchors.right: parent ? parent.right : undefined
    implicitHeight: popupItem.implicitHeight
    height: implicitHeight

    // Smooth Y displacement when the stack reorganizes.
    Behavior on y {
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

    // Exit is fade + shrink toward the card's own anchored edge, with NO
    // vertical translate. The translate used to move the card 20px into the
    // slot of its neighbour; while each popup was its own PanelWindow that
    // overshoot was clipped by the window bounds, but cards now share one
    // surface, so it drew straight over the card above — two same-coloured
    // rounded rects fusing into one block, read as the neighbour's bottom
    // edge being yanked down and snapping back.
    ParallelAnimation {
        id: exitAnim
        running: false
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

        // Width from the parent, NOT left/right anchors: an anchored item
        // ignores writes to `x`, which is what swipe-to-dismiss animates.
        width: parent.width

        transform: [
            Translate { y: popup._entranceTranslateY },
            Scale {
                origin.x: popupItem.width / 2
                origin.y: popup.isTop ? 0 : popupItem.height
                xScale: popup._exitScale * popup._entranceScale
                yScale: popup._exitScale * popup._entranceScale
            }
        ]
        // Entrance/exit fade and the swipe fade are independent; multiply
        // rather than letting either one overwrite the other.
        opacity: popup._entranceOpacity * popupItem.swipeOpacity

        // User intent only — the service decides what closing means and
        // whether the notification survives (a `resident` one does).
        onSwipeDismissed: NotificationService.dismissPopup(popup.notifId)
        onCloseClicked:   NotificationService.dismissPopup(popup.notifId)
        onActionInvoked:  (actionId) => NotificationService.invokeAction(popup.notifId, actionId)
        onTimeoutExpired: NotificationService.expirePopup(popup.notifId)
    }
}
