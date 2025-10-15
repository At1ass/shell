import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.src.ui.base
import qs.src.ui.containers
import qs.src.core.config
import qs.src.core.services
import "components" as NotifComponents

// Боковая панель с уведомлениями (slide-in справа)
Scope {
    id: root

    PanelWindow {
        id: sidebarWindow
        color: "transparent"

        implicitWidth: 420
        implicitHeight: screen.height

        anchors {
            top: true
            right: true
            bottom: true
        }

        exclusiveZone: 0
        visible: GlobalStates.notificationSidebarOpen

        WlrLayershell.namespace: "quickshell:notification-sidebar"
        WlrLayershell.layer: WlrLayer.Overlay

        // Focus grab для автозакрытия
        HyprlandFocusGrab {
            id: focusGrab
            active: sidebarLoader.active && GlobalStates.notificationSidebarOpen
            windows: [sidebarWindow]
            onCleared: {
                console.log("Notification sidebar focus lost, closing")
                GlobalStates.notificationSidebarOpen = false
            }
        }

        Loader {
            id: sidebarLoader
            active: GlobalStates.notificationSidebarOpen
            anchors.fill: parent

            sourceComponent: Item {
                id: sidebarContent
                anchors.fill: parent

                // Slide-in animation
                x: sidebarContent.width
                opacity: 0

                Component.onCompleted: {
                    x = 0
                    opacity = 1
                }

                Behavior on x {
                    NumberAnimation {
                        duration: Config.motion.duration.long2
                        easing.type: Config.motion.easing.emphasizedDecelerate
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Config.motion.duration.medium2
                        easing.type: Config.motion.easing.emphasizedDecelerate
                    }
                }

                // Backdrop scrim
                Rectangle {
                    anchors.fill: parent
                    anchors.rightMargin: sidebarCard.width + 16
                    color: Config.colors.scrim
                    opacity: 0.5

                    MouseArea {
                        anchors.fill: parent
                        onClicked: GlobalStates.notificationSidebarOpen = false
                    }
                }

                // Main sidebar card
                MaterialCard {
                    id: sidebarCard
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.margins: 8

                    implicitWidth: 400
                    color: Config.colors.surfaceContainerLow
                    radius: Config.shape.extraLarge
                    outlined: false

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 16

                        // Header
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            MaterialText {
                                Layout.fillWidth: true
                                text: "Notifications"
                                colorRole: "onSurface"
                                textStyle: "headlineSmall"
                                font.weight: Font.Medium
                            }

                            // DND toggle
                            IconButton {
                                iconName: NotificationService.dndEnabled ?
                                         "notifications_off" : "notifications"
                                iconSize: 24
                                onClicked: NotificationService.dndEnabled = !NotificationService.dndEnabled
                            }

                            // Clear all
                            IconButton {
                                iconName: "delete_sweep"
                                iconSize: 24
                                enabled: NotificationService.unreadCount > 0
                                onClicked: NotificationService.clearAll()
                            }

                            // Close
                            IconButton {
                                iconName: "close"
                                iconSize: 24
                                onClicked: GlobalStates.notificationSidebarOpen = false
                            }
                        }

                        // Count indicator
                        MaterialText {
                            Layout.fillWidth: true
                            text: NotificationService.unreadCount === 0 ?
                                  "No notifications" :
                                  `${NotificationService.unreadCount} notification${NotificationService.unreadCount > 1 ? 's' : ''}`
                            colorRole: "onSurfaceVariant"
                            textStyle: "bodyMedium"
                        }

                        // Scrollable notification list
                        ScrollView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            clip: true
                            contentWidth: availableWidth

                            ScrollBar.vertical: ScrollBar {
                                policy: ScrollBar.AsNeeded
                            }

                            ColumnLayout {
                                width: parent.width
                                spacing: 12

                                // Empty state
                                Item {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    Layout.minimumHeight: 200
                                    visible: NotificationService.unreadCount === 0

                                    ColumnLayout {
                                        anchors.centerIn: parent
                                        spacing: 16

                                        MaterialIcon {
                                            Layout.alignment: Qt.AlignHCenter
                                            iconName: "notifications_none"
                                            iconColor: Config.colors.onSurfaceVariant
                                            fontSize: 64
                                        }

                                        MaterialText {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: "All clear!"
                                            colorRole: "onSurfaceVariant"
                                            textStyle: "titleLarge"
                                        }

                                        MaterialText {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: "No notifications right now"
                                            colorRole: "onSurfaceVariant"
                                            textStyle: "bodyMedium"
                                        }
                                    }
                                }

                                // Notification groups
                                Repeater {
                                    model: NotificationService.appNames
                                    delegate: NotifComponents.NotificationGroup {
                                        required property string modelData
                                        Layout.fillWidth: true

                                        property string appKey: modelData
                                        property var group: (appKey && NotificationService.notificationsByApp)
                                               ? NotificationService.notificationsByApp[appKey]
                                               : null

                                        groupKey: appKey
                                        appName: group && group.displayName ? group.displayName : appKey
                                        notifications: group && group.notifications ? group.notifications : []
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    GlobalStates.notificationSidebarOpen = false
                }
            }
        }
    }
}
