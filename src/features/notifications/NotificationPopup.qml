import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.src.core.services
import QtQuick.Layouts

// Простая popup структура как в ii
Variants {
    model: Quickshell.screens

    Scope {
        required property ShellScreen modelData

        PanelWindow {
            id: popupWindow
            screen: modelData
            color: "transparent"
            visible: NotificationService.popupList.length > 0

            anchors {
                top: true
                right: true
            }

            margins {
                top: 48
                right: 16
            }

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "shell:notification-popups"
            exclusiveZone: 0

            implicitWidth: 360
            implicitHeight: notificationListView.contentHeight


            ColumnLayout {
                id: listColumn
                anchors.fill: parent
                spacing: 8

                ListView {
                    id: notificationListView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    interactive: false
                    model: ScriptModel {
                        values: NotificationService.popupList
                    }

                    delegate: NotificationItem {
                        required property var modelData
                        required property int index

                        notificationObject: modelData
                        Layout.fillWidth: true
                        Layout.preferredWidth: 360
                        // Layout.preferredHeight: 100
                    }
                }
            }
        }
    }
}
