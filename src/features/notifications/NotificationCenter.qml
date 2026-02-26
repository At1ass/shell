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
            focus: true
            width: AppConfig.notificationPanelWidth
            anchors {
                top: parent.top
                bottom: parent.bottom
                right: parent.right
            }
            anchors.margins: Tokens.spacing.medium
            z: 1

            // Keyboard navigation (arrows + vi j/k/x/gg/G)
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    GlobalStates.notificationCenterOpen = false
                    event.accepted = true
                } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                    notifList.decrementCurrentIndex()
                    event.accepted = true
                } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
                    notifList.incrementCurrentIndex()
                    event.accepted = true
                } else if (event.key === Qt.Key_Delete || event.key === Qt.Key_X) {
                    if (notifList.currentIndex >= 0 && notifList.currentIndex < notifList.count) {
                        const item = NotificationService.historyList.get(notifList.currentIndex)
                        if (item && item.notificationId) {
                            NotificationService.removeFromHistory(item.notificationId)
                        }
                    }
                    event.accepted = true
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (notifList.currentIndex >= 0 && notifList.currentIndex < notifList.count) {
                        const item = NotificationService.historyList.get(notifList.currentIndex)
                        if (item && AppConfig.notificationGroupByApp) {
                            NotificationService.toggleGroupExpanded(item.appName)
                        }
                    }
                    event.accepted = true
                } else if (event.key === Qt.Key_G) {
                    if (event.modifiers & Qt.ShiftModifier) {
                        // G — jump to last
                        notifList.currentIndex = notifList.count - 1
                    } else {
                        // g — jump to first
                        notifList.currentIndex = 0
                    }
                    event.accepted = true
                }
            }

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
                            text: "Notifications"
                            textStyle: "titleLarge"
                            colorRole: "onSurface"
                            font.weight: Font.Medium
                        }

                        Item { Layout.fillWidth: true }

                        IconButton {
                            iconName: NotificationService.doNotDisturb ? "notifications_off" : "do_not_disturb_on"
                            iconSize: Tokens.iconSize.large
                            variant: "standard"
                            onClicked: NotificationService.doNotDisturb = !NotificationService.doNotDisturb
                        }

                        MaterialButton {
                            text: "Clear"
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
                            keyNavigationEnabled: true
                            highlightFollowsCurrentItem: true

                            model: NotificationService.historyList

                            section.property: AppConfig.notificationGroupByApp ? "appName" : ""
                            section.delegate: NotificationGroupHeader {
                                required property string section
                                width: notifList.width
                                groupAppName: section
                                groupCount: NotificationService.getGroupCount(section)
                                groupAppIcon: NotificationService.getGroupIcon(section)
                                expanded: NotificationService.isGroupExpanded(section)
                                onToggleExpanded: NotificationService.toggleGroupExpanded(section)
                            }

                            delegate: NotificationHistoryItem {
                                required property int index
                                required property string notificationId
                                required property string summary
                                required property string body
                                required property string appName
                                required property string appIcon
                                required property string image
                                required property int urgency
                                required property int timestamp

                                width: notifList.width
                                visible: !AppConfig.notificationGroupByApp || NotificationService.isGroupExpanded(appName)
                                height: visible ? implicitHeight : 0

                                notificationObject: ({
                                    "notificationId": notificationId,
                                    "summary": summary,
                                    "body": body,
                                    "appName": appName,
                                    "appIcon": appIcon,
                                    "image": image,
                                    "actions": [],
                                    "urgency": urgency,
                                    "timestamp": timestamp
                                })
                            }
                        }

                        EmptyState {
                            anchors.fill: parent
                            visible: NotificationService.historyList.count === 0
                            iconName: "notifications_none"
                            title: "No notifications"
                            subtitle: "New notifications will appear here"
                        }
                    }
                }
            }
        }
    }
}
