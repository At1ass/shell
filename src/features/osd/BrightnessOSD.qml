pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.src.ui.containers
import qs.src.ui.base
import qs.src.core.config
import qs.src.core.services

Scope {
    id: root

    property bool osdVisible: false
    property real currentBrightness: 0.5

    Timer {
        id: hideTimer
        interval: AppConfig.osdTimeout
        repeat: false
        onTriggered: root.osdVisible = false
    }

    Connections {
        target: BrightnessService
        function onBrightnessAdjusted(value) {
            root.currentBrightness = value
            root.osdVisible = true
            hideTimer.restart()
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: osdWindow
            visible: root.osdVisible
            required property var modelData

            color: "transparent"
            anchors { top: true; left: false; right: false; bottom: false }
            margins { top: 80 }

            implicitWidth: 380
            implicitHeight: 120

            WlrLayershell.namespace: "quickshell:brightnessosd"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            exclusionMode: ExclusionMode.Ignore

            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                width: osdCard.width
                height: osdCard.height

                opacity: root.osdVisible ? 1 : 0
                scale: root.osdVisible ? 1 : 0.9

                Behavior on opacity {
                    NumberAnimation {
                        duration: Tokens.motion.duration.short4
                        easing.type: Tokens.motion.easing.emphasized
                    }
                }

                Behavior on scale {
                    NumberAnimation {
                        duration: Tokens.motion.duration.short4
                        easing.type: Tokens.motion.easing.emphasized
                    }
                }

                MaterialCard {
                    id: osdCard
                    width: 380
                    height: 100
                    color: Theme.surfaceContainerHigh
                    radius: Tokens.shape.extraLarge

                    Rectangle {
                        anchors.fill: parent
                        radius: osdCard.radius
                        color: Theme.primary
                        opacity: 0.08
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: osdCard.radius
                        border.color: Theme.outlineVariant
                        border.width: 1
                        color: "transparent"
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Tokens.spacing.large
                        spacing: Tokens.spacing.large

                        Rectangle {
                            width: 56
                            height: 56
                            radius: Tokens.shape.full
                            color: Theme.primaryContainer

                            MaterialIcon {
                                anchors.centerIn: parent
                                iconName: {
                                    const b = root.currentBrightness
                                    if (b < 0.34) return "brightness_low"
                                    if (b < 0.67) return "brightness_medium"
                                    return "brightness_high"
                                }
                                fontSize: 32
                                iconColor: Theme.onPrimaryContainer
                                backgroundColor: "transparent"
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Tokens.spacing.extraSmall

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Tokens.spacing.small

                                MaterialText {
                                    text: "Яркость"
                                    textStyle: "titleMedium"
                                    colorRole: "onSurface"
                                    font.weight: Font.Medium
                                }

                                Item { Layout.fillWidth: true }

                                MaterialText {
                                    text: Math.round(root.currentBrightness * 100) + "%"
                                    textStyle: "titleLarge"
                                    colorRole: "primary"
                                    font.weight: Font.Bold
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 8
                                radius: Tokens.shape.full
                                color: Theme.surfaceContainerHighest

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width * root.currentBrightness
                                    height: parent.height
                                    radius: Tokens.shape.full
                                    color: Theme.primary

                                    Behavior on width {
                                        NumberAnimation {
                                            duration: Tokens.motion.duration.short4
                                            easing.type: Tokens.motion.easing.emphasized
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
