import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.src.core.services
import "components" as NotifComponents

// Floating popup notifications (top-right corner)
Scope {
    id: root

    // Создаем popup window для каждого экрана
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: popupWindow
            required property var modelData

            screen: modelData
            color: "transparent"

            anchors {
                top: true
                right: true
            }

            margins {
                top: 48  // Под statusbar
                right: 8
            }

            implicitWidth: 400
            implicitHeight: Math.min(600, popupColumn.implicitHeight)

            exclusiveZone: 0

            mask: Region { item: popupColumn }

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell:notification-popups"

            ColumnLayout {
                id: popupColumn
                anchors.fill: parent
                spacing: 8
                readonly property int popupCount: Math.min(NotificationService.popupNotifications.length,
                                                            NotificationService.maxPopupCount)

                // Показываем только popup notifications
                Repeater {
                    model: popupColumn.popupCount
                    delegate: NotifComponents.NotificationItem {
                        required property int index
                        Layout.fillWidth: true
                        property QtObject currentNotification: NotificationService.popupNotifications[index]
                        notification: currentNotification
                        visible: !!currentNotification
                        enabled: !!currentNotification
                        isPopup: true
                        showAppName: true
                    }
                }
            }
        }
    }
}
