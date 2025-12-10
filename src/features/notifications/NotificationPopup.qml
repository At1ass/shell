import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.src.core.services
import qs.src.core.config
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

                    delegate: Item {
                        id: wrapper
                        required property var modelData
                        required property int index

                        width: notificationListView.width
                        height: notifItem.height
                        clip: true

                        // MD3 Collapse animation при удалении (150ms)
                        ListView.onRemove: SequentialAnimation {
                            PropertyAction {
                                target: wrapper
                                property: "ListView.delayRemove"
                                value: true
                            }
                            NumberAnimation {
                                target: wrapper
                                property: "height"
                                to: 0
                                duration: Config.motion.duration.short3  // 150ms
                                easing.type: Config.motion.easing.standard
                                easing.bezierCurve: Config.motion.easing.standardPoints
                            }
                            PropertyAction {
                                target: wrapper
                                property: "ListView.delayRemove"
                                value: false
                            }
                        }

                        NotificationItem {
                            id: notifItem
                            notificationObject: modelData
                            width: 360
                        }
                    }
                }
            }
        }
    }
}
