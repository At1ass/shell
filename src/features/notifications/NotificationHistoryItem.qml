import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import qs.src.core.config
import qs.src.core.services
import qs.src.ui.base
import qs.src.ui.containers

MaterialCard {
    id: root
    property var notificationObject: null
    readonly property bool hasNotification: notificationObject !== null && notificationObject !== undefined
    property bool expanded: false
    implicitHeight: contentLayout.implicitHeight + (Config.spacing.medium * 2)

    color: root.hasNotification && notificationObject.urgency === NotificationUrgency.Critical
           ? Config.colors.errorContainer
           : Config.colors.surfaceContainerHigh
    radius: Config.shape.large
    outlined: true

    ColumnLayout {
        id: contentLayout
        anchors.fill: parent
        anchors.margins: Config.spacing.medium
        spacing: Config.spacing.small

        RowLayout {
            Layout.fillWidth: true
            spacing: Config.spacing.small

            Image {
                visible: root.hasNotification && notificationObject.appIcon !== ""
                source: root.hasNotification && notificationObject.appIcon
                        ? Quickshell.iconPath(notificationObject.appIcon)
                        : ""
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                fillMode: Image.PreserveAspectFit
                sourceSize.width: 28
                sourceSize.height: 28
                smooth: true
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: 2

                MaterialText {
                    text: root.hasNotification ? (notificationObject.appName || "") : ""
                    textStyle: "labelLarge"
                    colorRole: root.hasNotification && notificationObject.urgency === NotificationUrgency.Critical
                               ? "onErrorContainer"
                               : "onSurface"
                    visible: text.length > 0
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                }

                MaterialText {
                    text: root.hasNotification ? (notificationObject.summary || "") : ""
                    textStyle: "titleSmall"
                    colorRole: root.hasNotification && notificationObject.urgency === NotificationUrgency.Critical
                               ? "onErrorContainer"
                               : "onSurface"
                    visible: text.length > 0
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.WrapAnywhere
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                }
            }

            MaterialText {
                text: root.hasNotification ? root.formatTime(notificationObject.timestamp) : ""
                textStyle: "labelSmall"
                colorRole: root.hasNotification && notificationObject.urgency === NotificationUrgency.Critical
                           ? "onErrorContainer"
                           : "onSurfaceVariant"
                visible: root.hasNotification && notificationObject.timestamp !== undefined
            }

            IconButton {
                iconName: root.expanded ? "expand_less" : "expand_more"
                iconSize: Config.iconSize.medium
                variant: "standard"
                visible: root.hasNotification && !!notificationObject.body
                onClicked: root.expanded = !root.expanded
            }

            IconButton {
                iconName: "close"
                iconSize: Config.iconSize.medium
                variant: "standard"
                onClicked: {
                    if (root.hasNotification) {
                        NotificationService.removeFromHistory(notificationObject.notificationId)
                    }
                }
            }
        }

        MaterialText {
            text: root.hasNotification ? (notificationObject.body || "") : ""
            textStyle: "bodySmall"
            colorRole: root.hasNotification && notificationObject.urgency === NotificationUrgency.Critical
                       ? "onErrorContainer"
                       : "onSurfaceVariant"
            visible: text.length > 0
            wrapMode: Text.WrapAnywhere
            maximumLineCount: root.expanded ? 0 : 3
            elide: root.expanded ? Text.ElideNone : Text.ElideRight
            Layout.fillWidth: true
            Layout.minimumWidth: 0
        }

        ColumnLayout {
            spacing: Config.spacing.extraSmall
            visible: root.hasNotification &&
                     notificationObject.actions &&
                     notificationObject.actions.length > 0

            Repeater {
                model: root.hasNotification ? (notificationObject.actions || []) : []

                MaterialButton {
                    required property var modelData
                    text: modelData.text
                    variant: "text"
                    onClicked: {
                        if (root.hasNotification) {
                            NotificationService.attemptInvokeAction(
                                notificationObject.notificationId,
                                modelData.identifier
                            )
                        }
                    }
                }
            }
        }
    }

    function formatTime(timestamp) {
        if (!timestamp) return ""
        const date = new Date(timestamp)
        return Qt.formatDateTime(date, "hh:mm")
    }
}
