import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Services.Notifications
import qs.src.core.services
import qs.src.core.config
import qs.src.ui.base
import qs.src.ui.feedback

Rectangle {
    id: root
    required property var notificationObject
    property bool animatePopupExit: true
    readonly property bool hasNotification: notificationObject !== null && notificationObject !== undefined
    readonly property bool isCritical: root.hasNotification && notificationObject.urgency === NotificationUrgency.Critical
    readonly property real progressValue: (root.hasNotification && notificationObject.progress !== undefined)
        ? notificationObject.progress
        : 1.0

    // Swipe-to-dismiss state
    property real _dragStartX: 0
    property bool _swiping: false
    property string _pendingDismissId: ""

    implicitWidth: 336
    readonly property real nonAnimHeight: column.implicitHeight + Tokens.spacing.medium * 2
    implicitHeight: nonAnimHeight
    radius: Tokens.shape.extraSmall  // MD3: 4dp

    // MD3: errorContainer for critical, surfaceContainerHighest for normal
    color: isCritical ? Theme.errorContainer : Theme.surfaceContainerHighest

    border.width: isCritical ? 2 : 0
    border.color: isCritical ? Theme.error : "transparent"

    // Initial state: off-screen right, invisible
    x: implicitWidth
    opacity: 0

    // One-shot entrance animation (replaces Timer + Behavior)
    ParallelAnimation {
        id: entranceAnim
        running: false
        NumberAnimation {
            target: root; property: "x"; to: 0
            duration: Tokens.motion.duration.medium2   // 300ms
            easing.type: Tokens.motion.easing.standard
            easing.bezierCurve: Tokens.motion.easing.standardPoints
        }
        NumberAnimation {
            target: root; property: "opacity"; to: 1.0
            duration: Tokens.motion.duration.short4   // 200ms
        }
    }

    Component.onCompleted: entranceAnim.start()

    // Snap-back animation for cancelled swipe
    ParallelAnimation {
        id: snapBackAnim
        NumberAnimation {
            target: root; property: "x"; to: 0
            duration: Tokens.motion.duration.short4   // 200ms
            easing.type: Tokens.motion.easing.standard
            easing.bezierCurve: Tokens.motion.easing.standardPoints
        }
        NumberAnimation {
            target: root; property: "opacity"; to: 1.0
            duration: Tokens.motion.duration.short3   // 150ms
        }
    }

    // Swipe dismiss animation
    SequentialAnimation {
        id: swipeDismissAnim
        NumberAnimation {
            target: root; property: "x"
            to: root.implicitWidth; duration: 150
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: root; property: "opacity"
            to: 0; duration: 50
        }
        ScriptAction {
            script: {
                root._swiping = false
                if (root._pendingDismissId !== "")
                    NotificationService.dismissActiveNotification(root._pendingDismissId)
                root._pendingDismissId = ""
            }
        }
    }

    // MD3 surface tint elevation
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: Theme.primary
        opacity: 0.08
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
                duration: 300
                easing.type: Easing.InOutQuad
            }
            NumberAnimation {
                target: criticalPulse; property: "opacity"
                from: 0.12; to: 0
                duration: 300
                easing.type: Easing.InOutQuad
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true

        onEntered: {
            if (root.hasNotification)
                NotificationService.incrementHover(notificationObject.notificationId)
        }
        onExited: {
            if (root.hasNotification)
                NotificationService.decrementHover(notificationObject.notificationId)
        }

        onPressed: (mouse) => {
            root._dragStartX = mouse.x
            root._swiping = false
        }
        onPositionChanged: (mouse) => {
            if (!pressed) return
            const dx = mouse.x - root._dragStartX
            if (Math.abs(dx) > 10) root._swiping = true
            if (root._swiping) {
                root.x = Math.max(0, dx)  // only swipe right
                root.opacity = 1.0 - (root.x / root.implicitWidth) * 0.5
            }
        }
        onReleased: (mouse) => {
            if (root._swiping && root.x > 70) {
                // Capture ID before animation — modelData binding may change during anim
                root._pendingDismissId = root.hasNotification ? notificationObject.notificationId : ""
                swipeDismissAnim.start()
            } else if (root._swiping) {
                // Snap back with explicit animation
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
                visible: root.hasNotification && source !== ""
                source: root.hasNotification && notificationObject.appIcon
                        ? Quickshell.iconPath(notificationObject.appIcon)
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

                Label {
                    text: root.hasNotification ? (notificationObject.appName || "") : ""
                    visible: text.length > 0
                    font.bold: true
                    color: isCritical ? Theme.onErrorContainer : Theme.onSurface
                    font.pixelSize: Tokens.typography.labelSmall.size
                }

                Label {
                    text: root.hasNotification ? (notificationObject.summary || "") : ""
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                    color: isCritical ? Theme.onErrorContainer : Theme.onSurface
                    font.pixelSize: Tokens.typography.bodyMedium.size
                }
            }

            // MD3 Close button
            Item {
                implicitWidth: 40
                implicitHeight: 40

                Rectangle {
                    id: closeButton
                    anchors.centerIn: parent
                    width: 32
                    height: 32
                    radius: width / 2
                    color: "transparent"

                    StateLayer {
                        layerColor: isCritical ? Theme.onErrorContainer : Theme.onSurface
                        hovered: closeMouseArea.containsMouse
                        pressed: closeMouseArea.pressed
                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        iconName: "close"
                        fontSize: Tokens.typography.titleMedium.size
                        iconColor: isCritical ? Theme.onErrorContainer : Theme.onSurfaceVariant
                        backgroundColor: "transparent"
                    }
                }

                MouseArea {
                    id: closeMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.hasNotification) {
                            NotificationService.dismissActiveNotification(notificationObject.notificationId)
                        }
                    }
                }
            }
        }

        Label {
            text: root.hasNotification ? (notificationObject.body || "") : ""
            visible: text.length > 0
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            color: isCritical ? Theme.onErrorContainer : Theme.onSurfaceVariant
            font.pixelSize: Tokens.typography.bodySmall.size
        }

        // Notification image
        Rectangle {
            visible: root.hasNotification && (notificationObject.image || "") !== ""
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? Math.min(notifImage.implicitHeight, 180) : 0
            radius: Tokens.shape.small
            clip: true
            color: "transparent"

            Image {
                id: notifImage
                anchors.fill: parent
                source: root.hasNotification ? (notificationObject.image || "") : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                sourceSize.width: parent.width
            }
        }

        Repeater {
            model: root.hasNotification ? (notificationObject.actions || []) : []

            MaterialButton {
                required property var modelData
                text: modelData.text
                variant: "text"
                onClicked: {
                    if (root.hasNotification) {
                        NotificationService.attemptInvokeAction(notificationObject.notificationId, modelData.identifier)
                    }
                }
            }
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 2
        color: Theme.surfaceContainerHighest
        opacity: 0.6

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
}
