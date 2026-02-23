import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Services.Notifications
import qs.src.core.services
import qs.src.core.config
import qs.src.ui.base as Base
import qs.src.ui.feedback

Rectangle {
    id: root
    required property var notificationObject
    property bool animatePopupExit: true
    readonly property bool hasNotification: notificationObject !== null && notificationObject !== undefined
    readonly property real progressValue: (root.hasNotification && notificationObject.progress !== undefined)
        ? notificationObject.progress
        : 1.0

    implicitWidth: 336
    readonly property real nonAnimHeight: column.implicitHeight + 24
    implicitHeight: nonAnimHeight
    radius: Tokens.shape.extraSmall  // MD3: 4dp

    // MD3: errorContainer for critical, surfaceContainerHighest for normal
    color: root.hasNotification && notificationObject.urgency === NotificationUrgency.Critical
           ? Theme.errorContainer
           : Theme.surfaceContainerHighest

    // Start off-screen right, slide in on completion
    x: implicitWidth
    opacity: 0

    // Behavior анимирует ИЗМЕНЕНИЕ свойств, не создание компонента
    Behavior on x {
        NumberAnimation {
            duration: Tokens.motion.duration.medium2  // 300ms
            easing.type: Tokens.motion.easing.standard
            easing.bezierCurve: Tokens.motion.easing.standardPoints
        }
    }

    Behavior on opacity {
        NumberAnimation {
            duration: Tokens.motion.duration.medium2
            easing.type: Tokens.motion.easing.standard
            easing.bezierCurve: Tokens.motion.easing.standardPoints
        }
    }

    Component.onCompleted: {
        root.x = 0;
        root.opacity = 1.0;
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onEntered: {
            if (root.hasNotification) {
                NotificationService.pauseTimeout(notificationObject.notificationId)
            }
        }
        onExited: {
            if (root.hasNotification) {
                NotificationService.resumeTimeout(notificationObject.notificationId)
            }
        }
    }

    ColumnLayout {
        id: column
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        RowLayout {
            spacing: 8
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
                    color: root.hasNotification && notificationObject.urgency === NotificationUrgency.Critical
                           ? Theme.onErrorContainer
                           : Theme.onSurface
                    font.pixelSize: Tokens.typography.labelSmall.size
                }

                Label {
                    text: root.hasNotification ? (notificationObject.summary || "") : ""
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                    color: root.hasNotification && notificationObject.urgency === NotificationUrgency.Critical
                           ? Theme.onErrorContainer
                           : Theme.onSurface
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
                        layerColor: root.hasNotification && notificationObject.urgency === NotificationUrgency.Critical
                                    ? Theme.onErrorContainer
                                    : Theme.onSurface
                        hovered: closeMouseArea.containsMouse
                        pressed: closeMouseArea.pressed
                    }

                    Base.MaterialIcon {
                        anchors.centerIn: parent
                        iconName: "close"
                        fontSize: Tokens.typography.titleMedium.size
                        iconColor: root.hasNotification && notificationObject.urgency === NotificationUrgency.Critical
                                   ? Theme.onErrorContainer
                                   : Theme.onSurfaceVariant
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
            color: root.hasNotification && notificationObject.urgency === NotificationUrgency.Critical
                   ? Theme.onErrorContainer
                   : Theme.onSurfaceVariant
            font.pixelSize: Tokens.typography.bodySmall.size
        }

        Repeater {
            model: root.hasNotification ? (notificationObject.actions || []) : []

            Base.MaterialButton {
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
                }
            }
        }
    }
}
