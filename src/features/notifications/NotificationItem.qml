import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Services.Notifications
import qs.src.core.services

Rectangle {
    id: root
    required property var notificationObject

    implicitWidth: 336
    implicitHeight: column.implicitHeight + 24
    radius: 12

    color: notificationObject.urgency === "Critical"
           ? Qt.rgba(0.6, 0, 0, 0.9)
           : Qt.rgba(0.12, 0.12, 0.12, 0.9)

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
                    color: "white"
                    font.pixelSize: 12
                }

                Label {
                    text: notificationObject.summary || ""
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                    color: "white"
                    font.pixelSize: 14
                }
            }

            ToolButton {
                text: "×"
                font.pixelSize: 20
                onClicked: NotificationService.discardNotification(notificationObject.notificationId)
            }
        }

        Label {
            text: notificationObject.body || ""
            visible: text.length > 0
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            color: "#e0e0e0"
            font.pixelSize: 12
        }

        Repeater {
            model: notificationObject.actions || []

            Button {
                required property var modelData
                text: modelData.text
                onClicked: NotificationService.attemptInvokeAction(notificationObject.notificationId, modelData.identifier)
            }
        }
    }
}
