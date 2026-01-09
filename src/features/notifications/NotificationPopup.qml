import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.src.core.services
import qs.src.core.config

// Простая popup структура как в ii
Variants {
    model: Quickshell.screens

    Scope {
        required property ShellScreen modelData

        PanelWindow {
            id: popupWindow
            screen: modelData
            color: "transparent"
            visible: true
            property real listHeight: 0

            function calcListHeight() {
                const count = notificationListView.count;
                if (count === 0)
                    return 0;
                let height = (count - 1) * 8;
                for (let i = 0; i < count; i++) {
                    const item = notificationListView.itemAtIndex(i);
                    if (item && item.nonAnimHeight !== undefined)
                        height += item.nonAnimHeight;
                }
                return height;
            }

            function updateListHeight() {
                listHeight = calcListHeight();
            }

            implicitHeight: NotificationService.activeList.count > 0
                ? listHeight
                : 0

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

            ListView {
                id: notificationListView
                width: parent.width
                height: contentHeight
                interactive: false
                spacing: 0
                reuseItems: false
                model: NotificationService.activeList
                onCountChanged: popupWindow.updateListHeight()
                onContentHeightChanged: popupWindow.updateListHeight()
                move: Transition {
                    NumberAnimation {
                        property: "y"
                        duration: Config.motion.duration.short3
                        easing.type: Config.motion.easing.standard
                        easing.bezierCurve: Config.motion.easing.standardPoints
                    }
                }
                displaced: Transition {
                    NumberAnimation {
                        property: "y"
                        duration: Config.motion.duration.short3
                        easing.type: Config.motion.easing.standard
                        easing.bezierCurve: Config.motion.easing.standardPoints
                    }
                }

                delegate: Item {
                    id: wrapper
                    required property int index
                    property int stableIndex: 0
                    required property string notificationId
                    required property string summary
                    required property string body
                    required property string appName
                    required property string appIcon
                    required property string image
                    required property var actions
                    required property int urgency
                    required property int timestamp
                    required property real progress
                    property var entry: ({})
                    readonly property real nonAnimHeight: notifItem.nonAnimHeight

                    onIndexChanged: {
                        if (index !== -1)
                            stableIndex = index;
                    }

                    function updateEntry() {
                        entry = {
                            "notificationId": notificationId || "",
                            "summary": summary || "",
                            "body": body || "",
                            "appName": appName || "",
                            "appIcon": appIcon || "",
                            "image": image || "",
                            "actions": actions || [],
                            "urgency": urgency,
                            "timestamp": timestamp || 0,
                            "progress": isFinite(progress) ? progress : 1.0
                        };
                    }

                    Component.onCompleted: updateEntry()
                    onNotificationIdChanged: updateEntry()
                    onSummaryChanged: updateEntry()
                    onBodyChanged: updateEntry()
                    onAppNameChanged: updateEntry()
                    onAppIconChanged: updateEntry()
                    onImageChanged: updateEntry()
                    onActionsChanged: updateEntry()
                    onUrgencyChanged: updateEntry()
                    onTimestampChanged: updateEntry()
                    onProgressChanged: updateEntry()

                    width: notificationListView.width
                    implicitHeight: notifItem.implicitHeight + (stableIndex === 0 ? 0 : 8)
                    height: implicitHeight
                    clip: true

                    // MD3 Collapse animation при удалении (150ms)
                    SequentialAnimation {
                        id: removeAnimation
                        PropertyAction {
                            target: wrapper
                            property: "ListView.delayRemove"
                            value: true
                        }
                        PropertyAction {
                            target: wrapper
                            property: "enabled"
                            value: false
                        }
                        PropertyAction {
                            target: wrapper
                            property: "z"
                            value: 1
                        }
                        NumberAnimation {
                            target: notifItem
                            property: "x"
                            to: 400
                            duration: Config.motion.duration.short3  // 150ms
                            easing.type: Config.motion.easing.standard
                            easing.bezierCurve: Config.motion.easing.standardPoints
                        }
                        NumberAnimation {
                            target: notifItem
                            property: "opacity"
                            to: 0
                            duration: Config.motion.duration.short3  // 150ms
                            easing.type: Config.motion.easing.standard
                            easing.bezierCurve: Config.motion.easing.standardPoints
                        }
                        PropertyAction {
                            target: wrapper
                            property: "implicitHeight"
                            value: 0
                        }
                        PropertyAction {
                            target: wrapper
                            property: "ListView.delayRemove"
                            value: false
                        }
                    }

                    ListView.onRemove: removeAnimation.start()

                    NotificationItem {
                        id: notifItem
                        notificationObject: entry
                        animatePopupExit: false
                        width: 360
                        anchors.top: parent.top
                        anchors.topMargin: stableIndex === 0 ? 0 : 8
                    }
                }
            }

            Component.onCompleted: updateListHeight()
        }
    }
}
