import QtQuick
import QtQuick.Layouts
import qs.src.core.config
import qs.src.core.services
import qs.src.ui.base
import qs.src.ui.containers
import qs.src.ui.feedback

Item {
    id: panel
    width: 380

    anchors {
        top: parent.top
        bottom: parent.bottom
        right: parent.right
        margins: Config.spacing.medium
    }

    MaterialCard {
        anchors.fill: parent
        color: Config.colors.surfaceContainer
        radius: Config.shape.extraLarge
        outlined: false

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Config.spacing.medium
            spacing: Config.spacing.small

            RowLayout {
                Layout.fillWidth: true
                spacing: Config.spacing.small

                MaterialIcon {
                    iconName: "notifications"
                    fontSize: Config.typography.titleLarge.size
                    iconColor: Config.colors.primary
                    backgroundColor: "transparent"
                }

                MaterialText {
                    text: "Уведомления"
                    textStyle: "titleLarge"
                    colorRole: "onSurface"
                    font.weight: Font.Medium
                }

                Item { Layout.fillWidth: true }

                MaterialButton {
                    text: "Очистить"
                    variant: "text"
                    enabled: NotificationService.historyList.count > 0
                    onClicked: NotificationService.clearHistory()
                }
            }

            Divider {
                Layout.fillWidth: true
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ListView {
                    id: notifList
                    anchors.fill: parent
                    spacing: Config.spacing.small
                    clip: true

                    model: NotificationService.historyList

                    delegate: NotificationHistoryItem {
                        width: notifList.width
                        notificationObject: ({
                            "notificationId": notificationId,
                            "summary": summary,
                            "body": body,
                            "appName": appName,
                            "appIcon": appIcon,
                            "image": image,
                            "actions": actions,
                            "urgency": urgency,
                            "timestamp": timestamp
                        })
                    }
                }

                EmptyState {
                    anchors.fill: parent
                    visible: NotificationService.historyList.count === 0
                    iconName: "notifications_none"
                    title: "Нет уведомлений"
                    subtitle: "Новые уведомления появятся здесь"
                }
            }
        }
    }
}
