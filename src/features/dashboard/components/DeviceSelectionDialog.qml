import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.src.ui.containers
import qs.src.ui.base
import qs.src.core.config

Rectangle {
    id: root
    anchors.fill: parent
    color: Qt.rgba(0, 0, 0, 0.5)
    visible: false
    opacity: 0

    property var devices: []  // Array of device nodes
    property var selectedDevice: null
    property string dialogTitle: "Select Device"
    property string deviceType: "output"  // "output" or "input"

    signal deviceSelected(var device)
    signal cancelled()

    Behavior on opacity {
        NumberAnimation {
            duration: Config.motion.duration.medium2
            easing.type: Config.motion.easing.emphasizedDecelerate
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.close()
    }

    function open(devices, currentDevice, title, type) {
        root.devices = devices
        root.selectedDevice = currentDevice
        root.dialogTitle = title || "Select Device"
        root.deviceType = type || "output"
        root.visible = true
        root.opacity = 1
    }

    function close() {
        root.opacity = 0
        closeTimer.start()
    }

    Timer {
        id: closeTimer
        interval: Config.motion.duration.medium2
        onTriggered: {
            root.visible = false
            cancelled()
        }
    }

    MaterialCard {
        anchors.centerIn: parent
        width: Math.min(500, parent.width - Config.spacing.large * 2)
        height: Math.min(contentLayout.implicitHeight + Config.spacing.large * 2, parent.height - Config.spacing.large * 2)
        color: Config.colors.surfaceContainerHigh
        radius: Config.shape.extraLarge

        MouseArea {
            anchors.fill: parent
            onClicked: {} // Block clicks
        }

        ColumnLayout {
            id: contentLayout
            anchors.fill: parent
            anchors.margins: Config.spacing.large
            spacing: Config.spacing.medium

            // Header
            RowLayout {
                Layout.fillWidth: true
                spacing: Config.spacing.medium

                MaterialIcon {
                    iconName: root.deviceType === "output" ? "volume_up" : "mic"
                    fontSize: Config.typography.headlineMedium.size
                    iconColor: Config.colors.primary
                    backgroundColor: "transparent"
                }

                MaterialText {
                    text: root.dialogTitle
                    textStyle: "headlineSmall"
                    colorRole: "onSurface"
                    font.weight: Font.Bold
                }
            }

            // Device list
            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ScrollBar.vertical.policy: ScrollBar.AsNeeded

                ColumnLayout {
                    width: parent.width
                    spacing: Config.spacing.small

                    Repeater {
                        model: root.devices

                        delegate: Rectangle {
                            required property var modelData
                            property var device: modelData

                            Layout.fillWidth: true
                            height: 64
                            radius: Config.shape.medium
                            color: deviceMouseArea.containsMouse ? Config.colors.surfaceContainerHighest :
                                   device.id === root.selectedDevice?.id ? Config.colors.secondaryContainer : "transparent"

                            Behavior on color {
                                ColorAnimation { duration: Config.motion.duration.short4 }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: Config.spacing.medium
                                spacing: Config.spacing.medium

                                // Radio indicator
                                Rectangle {
                                    width: 20
                                    height: 20
                                    radius: 10
                                    color: "transparent"
                                    border.width: 2
                                    border.color: device.id === root.selectedDevice?.id ? Config.colors.primary : Config.colors.outline

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 10
                                        height: 10
                                        radius: 5
                                        color: Config.colors.primary
                                        visible: device.id === root.selectedDevice?.id
                                    }

                                    Behavior on border.color {
                                        ColorAnimation { duration: Config.motion.duration.short4 }
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    MaterialText {
                                        text: device.description || device.name || "Unknown Device"
                                        textStyle: "bodyLarge"
                                        colorRole: "onSurface"
                                        font.weight: device.id === root.selectedDevice?.id ? Font.Medium : Font.Normal
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }

                                    MaterialText {
                                        visible: device.id === root.selectedDevice?.id
                                        text: "Active"
                                        textStyle: "labelSmall"
                                        colorRole: "primary"
                                    }
                                }

                                MaterialIcon {
                                    visible: device.id === root.selectedDevice?.id
                                    iconName: "check"
                                    fontSize: Config.typography.titleMedium.size
                                    iconColor: Config.colors.primary
                                    backgroundColor: "transparent"
                                }
                            }

                            MouseArea {
                                id: deviceMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.deviceSelected(device)
                                    root.close()
                                }
                            }
                        }
                    }

                    // Empty state
                    Item {
                        visible: root.devices.length === 0
                        Layout.fillWidth: true
                        Layout.preferredHeight: 120

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: Config.spacing.small

                            MaterialIcon {
                                iconName: root.deviceType === "output" ? "speaker_notes_off" : "mic_off"
                                fontSize: Config.typography.displaySmall.size
                                iconColor: Config.colors.onSurfaceVariant
                                backgroundColor: "transparent"
                                Layout.alignment: Qt.AlignHCenter
                                opacity: 0.5
                            }

                            MaterialText {
                                text: "No devices available"
                                textStyle: "bodyMedium"
                                colorRole: "onSurfaceVariant"
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }
                    }
                }
            }

            // Cancel button
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                radius: 24
                color: cancelMouseArea.containsMouse ? Config.colors.surfaceContainerHighest : "transparent"

                Behavior on color {
                    ColorAnimation { duration: Config.motion.duration.short4 }
                }

                MaterialText {
                    anchors.centerIn: parent
                    text: "Cancel"
                    textStyle: "labelLarge"
                    colorRole: "primary"
                    font.weight: Font.Medium
                }

                MouseArea {
                    id: cancelMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.close()
                }
            }
        }
    }
}
