import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import qs.src.core.services
import qs.src.core.config

Variants {
    model: Quickshell.screens

    PanelWindow {
        id: popupWindow
        required property ShellScreen modelData
        screen: modelData
        color: "transparent"

        // Conditional visibility with grace period for exit animations
        visible: NotificationService.activeList.count > 0 || hideDelayTimer.running

        Timer {
            id: hideDelayTimer
            interval: 500
            repeat: false
        }

        Connections {
            target: NotificationService.activeList
            function onCountChanged() {
                if (NotificationService.activeList.count === 0)
                    hideDelayTimer.restart()
            }
        }

        // Window height tracks ListView contentHeight directly — no manual
        // calcListHeight that can desync with actual delegate sizes.
        implicitHeight: notificationListView.contentHeight

        anchors {
            top: true
            right: true
        }

        margins {
            top: AppConfig.barHeight
            right: AppConfig.barMargin
        }

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "shell:notification-popups"
        exclusiveZone: 0

        // Click-through mask: only notification content is interactive
        mask: Region {
            item: notificationListView.contentItem
        }

        implicitWidth: AppConfig.notificationPopupWidth

        ListView {
            id: notificationListView
            width: parent.width
            height: contentHeight
            interactive: false
            spacing: 8
            reuseItems: false
            model: NotificationService.activeList
            move: Transition {
                NumberAnimation {
                    property: "y"
                    duration: Tokens.motion.duration.short3
                    easing.type: Tokens.motion.easing.standard
                    easing.bezierCurve: Tokens.motion.easing.standardPoints
                }
            }
            displaced: Transition {
                NumberAnimation {
                    property: "y"
                    duration: Tokens.motion.duration.short3
                    easing.type: Tokens.motion.easing.standard
                    easing.bezierCurve: Tokens.motion.easing.standardPoints
                }
            }

            delegate: Item {
                id: wrapper
                required property int index
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

                // Coalesce multiple property changes into single updateEntry call
                Component.onCompleted: updateEntry()
                onNotificationIdChanged: Qt.callLater(updateEntry)
                onSummaryChanged: Qt.callLater(updateEntry)
                onBodyChanged: Qt.callLater(updateEntry)
                onAppNameChanged: Qt.callLater(updateEntry)
                onAppIconChanged: Qt.callLater(updateEntry)
                onImageChanged: Qt.callLater(updateEntry)
                onActionsChanged: Qt.callLater(updateEntry)
                onUrgencyChanged: Qt.callLater(updateEntry)
                onTimestampChanged: Qt.callLater(updateEntry)
                onProgressChanged: Qt.callLater(updateEntry)

                width: notificationListView.width
                implicitHeight: notifItem.implicitHeight
                height: implicitHeight
                clip: true

                // MD3 Collapse animation on removal
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
                    // Slide out to the right
                    NumberAnimation {
                        target: notifItem
                        property: "x"
                        to: notifItem.implicitWidth
                        duration: Tokens.motion.duration.short3
                        easing.type: Tokens.motion.easing.standard
                        easing.bezierCurve: Tokens.motion.easing.standardPoints
                    }
                    // Collapse height smoothly so neighbours don't jump
                    NumberAnimation {
                        target: wrapper
                        property: "implicitHeight"
                        to: 0
                        duration: Tokens.motion.duration.short3
                        easing.type: Tokens.motion.easing.standard
                        easing.bezierCurve: Tokens.motion.easing.standardPoints
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
                    width: AppConfig.notificationPopupWidth
                    anchors.top: parent.top
                }
            }
        }
    }
}
