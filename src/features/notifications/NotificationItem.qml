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

    implicitWidth: 336
    implicitHeight: column.implicitHeight + 24
    radius: Config.shape.extraSmall  // MD3: 4dp

    // MD3: errorContainer for critical, surfaceContainerHighest for normal
    color: notificationObject.urgency === NotificationUrgency.Critical
           ? Config.colors.errorContainer
           : Config.colors.surfaceContainerHighest

    // MD3 Animations: используем Behavior как в Caelestia
    // Начальное положение - за экраном справа
    x: 400
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

    // Таймер для unlock после завершения exit animation
    Timer {
        id: unlockTimer
        interval: Config.motion.duration.medium2
        onTriggered: notificationObject.unlock(root)
    }

    // Отслеживаем изменение popup флага для exit animation
    Connections {
        target: notificationObject
        function onPopupChanged() {
            if (!notificationObject.popup) {
                // Exit: двигаем обратно за экран
                root.x = 400;
                root.opacity = 0;
                // Unlock после завершения анимации
                unlockTimer.start();
            }
        }
    }

    Component.onCompleted: {
        // Блокируем удаление во время существования делегата
        notificationObject.lock(root);
        // Просто меняем position - Behavior запустит анимацию
        root.x = 0;
        root.opacity = 1.0;
    }

    Component.onDestruction: {
        notificationObject.unlock(root);
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
                visible: source !== ""
                source: notificationObject.appIcon ? Quickshell.iconPath(notificationObject.appIcon) : ""
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
                    text: notificationObject.appName || ""
                    visible: text.length > 0
                    font.bold: true
                    color: notificationObject.urgency === NotificationUrgency.Critical
                           ? Config.colors.onErrorContainer
                           : Config.colors.onSurface
                    font.pixelSize: 12
                }

                Label {
                    text: notificationObject.summary || ""
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                    color: notificationObject.urgency === NotificationUrgency.Critical
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
                        color: notificationObject.urgency === NotificationUrgency.Critical
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
                        color: notificationObject.urgency === NotificationUrgency.Critical
                               ? Config.colors.onErrorContainer
                               : Config.colors.onSurfaceVariant
                    }
                }

                MouseArea {
                    id: closeMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: NotificationService.discardNotification(notificationObject.notificationId)
                }
            }
        }

        Label {
            text: notificationObject.body || ""
            visible: text.length > 0
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            color: notificationObject.urgency === NotificationUrgency.Critical
                   ? Config.colors.onErrorContainer
                   : Config.colors.onSurfaceVariant
            font.pixelSize: 12
        }

        Repeater {
            model: notificationObject.actions || []

            Base.MaterialButton {
                required property var modelData
                text: modelData.text
                variant: "text"
                onClicked: NotificationService.attemptInvokeAction(notificationObject.notificationId, modelData.identifier)
            }
        }
    }
}
