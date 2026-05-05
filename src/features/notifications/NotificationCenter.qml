import QtQuick
import QtQuick.Controls
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

        // Scrim overlay
        Rectangle {
            anchors.fill: parent
            color: "black"
            opacity: panelSlide.visible ? 0.32 : 0
            visible: GlobalStates.notificationCenterOpen

            Behavior on opacity {
                NumberAnimation {
                    duration: Tokens.motion.duration.medium2
                    easing.type: Tokens.motion.easing.standard
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: GlobalStates.notificationCenterOpen = false
            }
        }

        Item {
            id: panelSlide
            width: AppConfig.notificationPanelWidth
            anchors {
                top: parent.top
                bottom: parent.bottom
                right: parent.right
            }
            anchors.margins: Tokens.spacing.medium
            z: 1
            visible: GlobalStates.notificationCenterOpen

            // Slide-in animation
            property real _slideX: visible ? 0 : panelSlide.width + Tokens.spacing.medium
            property real _slideOpacity: visible ? 1.0 : 0

            transform: Translate { x: panelSlide._slideX }
            opacity: panelSlide._slideOpacity

            Behavior on _slideX {
                NumberAnimation {
                    duration: Tokens.motion.duration.medium2
                    easing.type: Tokens.motion.easing.emphasizedDecelerate
                    easing.bezierCurve: Tokens.motion.easing.emphasizedDeceleratePoints
                }
            }

            Behavior on _slideOpacity {
                NumberAnimation {
                    duration: Tokens.motion.duration.medium1
                    easing.type: Tokens.motion.easing.standard
                }
            }

            focus: true

            // Keyboard navigation
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
                        notifList.currentIndex = notifList.count - 1
                    } else {
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

                    // Header
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

                        // DND toggle
                        IconButton {
                            iconName: NotificationService.doNotDisturb ? "notifications_off" : "do_not_disturb_on"
                            iconSize: Tokens.iconSize.large
                            variant: "standard"
                            onClicked: NotificationService.doNotDisturb = !NotificationService.doNotDisturb

                            Rectangle {
                                anchors.fill: parent
                                radius: Tokens.shape.full
                                color: NotificationService.doNotDisturb ? Theme.errorContainer : "transparent"
                                opacity: NotificationService.doNotDisturb ? 0.3 : 0
                                z: -1

                                Behavior on opacity {
                                    NumberAnimation { duration: Tokens.motion.duration.short3 }
                                }
                            }
                        }

                        MaterialButton {
                            text: "Clear all"
                            variant: "text"
                            enabled: NotificationService.historyList.count > 0
                            onClicked: NotificationService.clearHistory()
                        }
                    }

                    // Count indicator
                    MaterialText {
                        text: {
                            const count = NotificationService.historyList.count
                            if (count === 0) return ""
                            return count + (count === 1 ? " notification" : " notifications")
                        }
                        visible: text.length > 0
                        textStyle: "labelMedium"
                        colorRole: "onSurfaceVariant"
                        Layout.fillWidth: true
                    }

                    Divider {
                        Layout.fillWidth: true
                    }

                    // Notification list
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        ListView {
                            id: notifList
                            anchors.fill: parent
                            spacing: 0
                            clip: true
                            keyNavigationEnabled: true
                            highlightFollowsCurrentItem: true

                            model: NotificationService.historyList

                            section.property: AppConfig.notificationGroupByApp ? "appName" : ""
                            section.delegate: NotificationGroupHeader {
                                required property string section
                                width: notifList.width
                                height: implicitHeight + Tokens.spacing.small
                                groupAppName: section
                                groupCount: NotificationService.getGroupCount(section)
                                groupAppIcon: NotificationService.getGroupIcon(section)
                                expanded: NotificationService.isGroupExpanded(section)
                                onToggleExpanded: NotificationService.toggleGroupExpanded(section)
                            }

                            delegate: Column {
                                required property int index
                                required property string notificationId
                                required property string summary
                                required property string body
                                required property string appName
                                required property string appIcon
                                required property string image
                                required property int urgency
                                required property int timestamp

                                readonly property bool itemVisible: !AppConfig.notificationGroupByApp || NotificationService.isGroupExpanded(appName)

                                width: notifList.width
                                height: itemVisible ? implicitHeight : 0
                                visible: itemVisible

                                NotificationHistoryItem {
                                    width: parent.width
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

                                Item {
                                    width: 1
                                    height: Tokens.spacing.small
                                }
                            }

                            // Smooth scroll
                            ScrollBar.vertical: ScrollBar {
                                active: notifList.moving || hovered
                                policy: ScrollBar.AsNeeded
                            }

                            add: Transition {
                                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Tokens.motion.duration.short4 }
                                NumberAnimation { property: "scale"; from: 0.95; to: 1; duration: Tokens.motion.duration.short4 }
                            }

                            remove: Transition {
                                NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Tokens.motion.duration.short3 }
                            }

                            displaced: Transition {
                                NumberAnimation { properties: "y"; duration: Tokens.motion.duration.medium1; easing.type: Tokens.motion.easing.standard }
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
