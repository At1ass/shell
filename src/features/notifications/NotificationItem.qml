import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Services.Notifications
import qs.src.core.services
import qs.src.core.config
import qs.src.ui.base as Base

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
    radius: Config.shape.extraSmall  // MD3: 4dp

    // MD3: errorContainer for critical, surfaceContainerHighest for normal
    color: root.hasNotification && notificationObject.urgency === NotificationUrgency.Critical
           ? Config.colors.errorContainer
           : Config.colors.surfaceContainerHighest

    // Start off-screen right, slide in on completion
    x: implicitWidth
    opacity: 0

    // Behavior анимирует ИЗМЕНЕНИЕ свойств, не создание компонента
    Behavior on x {
        NumberAnimation {
            duration: Config.motion.duration.medium2  // 300ms
            easing.type: Config.motion.easing.standard
            easing.bezierCurve: Config.motion.easing.standardPoints
        }
    }

    Behavior on opacity {
        NumberAnimation {
            duration: Config.motion.duration.medium2
            easing.type: Config.motion.easing.standard
            easing.bezierCurve: Config.motion.easing.standardPoints
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
                           ? Config.colors.onErrorContainer
                           : Config.colors.onSurface
                    font.pixelSize: 12
                }

                Label {
                    text: root.hasNotification ? (notificationObject.summary || "") : ""
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                    color: root.hasNotification && notificationObject.urgency === NotificationUrgency.Critical
                           ? Config.colors.onErrorContainer
                           : Config.colors.onSurface
                    font.pixelSize: 14
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

                    // State layer
                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: root.hasNotification && notificationObject.urgency === NotificationUrgency.Critical
                               ? Config.colors.onErrorContainer
                               : Config.colors.onSurface
                        opacity: closeMouseArea.pressed ? Config.stateLayer.pressedOpacity :
                                 closeMouseArea.containsMouse ? Config.stateLayer.hoverOpacity : 0.0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Config.motion.duration.short4
                                easing.type: Config.motion.easing.standard
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "×"
                        font.pixelSize: 20
                        color: root.hasNotification && notificationObject.urgency === NotificationUrgency.Critical
                               ? Config.colors.onErrorContainer
                               : Config.colors.onSurfaceVariant
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
                   ? Config.colors.onErrorContainer
                   : Config.colors.onSurfaceVariant
            font.pixelSize: 12
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
        color: Config.colors.surfaceContainerHighest
        opacity: 0.6

        Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            height: parent.height
            width: parent.width * Math.max(0, Math.min(1, root.progressValue))
            color: Config.colors.primary

            Behavior on width {
                NumberAnimation {
                    duration: Config.motion.duration.short4
                    easing.type: Config.motion.easing.standard
                }
            }
        }
    }
}
