pragma ComponentBehavior: Bound
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
        visible: NotificationService.activeList.length > 0 || hideDelayTimer.running

        Timer {
            id: hideDelayTimer
            interval: 500
            repeat: false
        }

        Connections {
            target: NotificationService
            function onActiveListChanged() {
                if (NotificationService.activeList.length === 0)
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
            implicitHeight: contentHeight
            interactive: false
            spacing: Tokens.spacing.small
            model: ScriptModel {
                objectProp: "notificationId"
                values: NotificationService.activeList
            }

            displaced: Transition {
                NumberAnimation {
                    properties: "x,y"
                    duration: Tokens.motion.duration.medium1   // 250ms
                    easing.type: Tokens.motion.easing.standard
                    easing.bezierCurve: Tokens.motion.easing.standardPoints
                }
            }

            delegate: Item {
                id: wrapper
                required property var modelData
                required property int index

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
                    // If already swiped, skip visible slide-out
                    ScriptAction {
                        script: {
                            if (notifItem._swiping || notifItem.x > 10) {
                                wrapper.opacity = 0
                            }
                        }
                    }
                    // Parallel slide-out + fade (200ms)
                    ParallelAnimation {
                        NumberAnimation {
                            target: wrapper; property: "x"
                            to: wrapper.width
                            duration: Tokens.motion.duration.short4   // 200ms
                            easing.type: Tokens.motion.easing.emphasizedAccelerate
                            easing.bezierCurve: Tokens.motion.easing.emphasizedAcceleratePoints
                        }
                        NumberAnimation {
                            target: wrapper; property: "opacity"
                            to: 0
                            duration: Tokens.motion.duration.short3   // 150ms
                        }
                    }
                    // Collapse height so neighbours fill the gap (150ms)
                    NumberAnimation {
                        target: wrapper
                        property: "implicitHeight"
                        to: 0
                        duration: Tokens.motion.duration.short3   // 150ms
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
                    notificationObject: wrapper.modelData
                    animatePopupExit: false
                    width: AppConfig.notificationPopupWidth
                    anchors.top: parent.top
                }
            }
        }
    }
}
