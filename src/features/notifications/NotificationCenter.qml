import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.src.core.config
import qs.src.core.services
import qs.src.ui.base
import qs.src.ui.containers
import qs.src.ui.feedback

Scope {
    PanelWindow {
        id: centerWindow
        visible: GlobalStates.notificationCenterOpen
        focusable: true
        color: "transparent"

        anchors {
            left: true
            right: true
            top: true
            bottom: true
        }

        exclusiveZone: 0
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell:notification-center"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        HyprlandFocusGrab {
            active: GlobalStates.notificationCenterOpen
            windows: [centerWindow]
            onCleared: GlobalStates.notificationCenterOpen = false
        }

        MouseArea {
            anchors.fill: parent
            onClicked: (mouse) => {
                const insidePanel = mouse.x >= panel.x &&
                                    mouse.x <= panel.x + panel.width &&
                                    mouse.y >= panel.y &&
                                    mouse.y <= panel.y + panel.height
                if (!insidePanel) {
                    GlobalStates.notificationCenterOpen = false
                }
            }
        }

        Item {
            id: panel
            width: AppConfig.notificationPanelWidth
            anchors {
                top: parent.top
                bottom: parent.bottom
                right: parent.right
            }
            anchors.margins: Tokens.spacing.medium
            z: 1

            MaterialCard {
                anchors.fill: parent
                color: Theme.surfaceContainer
                radius: Tokens.shape.extraLarge

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Tokens.spacing.medium
                    spacing: Tokens.spacing.small

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.small

                        MaterialIcon {
                            iconName: "notifications"
                            fontSize: Tokens.typography.titleLarge.size
                            iconColor: Theme.primary
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
                            spacing: Tokens.spacing.small
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
    }
}
