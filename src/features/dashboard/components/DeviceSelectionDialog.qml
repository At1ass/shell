import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.src.ui.containers
import qs.src.ui.base
import qs.src.ui.feedback
import qs.src.core.config

Dialog {
    id: root
    dialogWidth: Math.min(500, parent.width - Tokens.spacing.large * 2)

    property var devices: []  // Array of device nodes
    property var selectedDevice: null
    property string dialogTitle: "Select Device"
    property string deviceType: "output"  // "output" or "input"

    signal deviceSelected(var device)
    signal cancelled()

    onClosed: cancelled()

    function openDialog(devices, currentDevice, title, type) {
        root.devices = devices
        root.selectedDevice = currentDevice
        root.dialogTitle = title || "Select Device"
        root.deviceType = type || "output"
        root.open()
    }

    ColumnLayout {
        id: contentLayout
        anchors.fill: parent
        anchors.margins: Tokens.spacing.large
        spacing: Tokens.spacing.medium

            // Header
            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.medium

                MaterialIcon {
                    iconName: root.deviceType === "output" ? "volume_up" : "mic"
                    fontSize: Tokens.typography.headlineMedium.size
                    iconColor: Theme.primary
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
            ScrollableList {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Tokens.spacing.small

                Repeater {
                        model: root.devices

                        delegate: Rectangle {
                            required property var modelData
                            property var device: modelData

                            Layout.fillWidth: true
                            height: 64
                            radius: Tokens.shape.medium
                            color: deviceMouseArea.containsMouse ? Theme.surfaceContainerHighest :
                                   device.id === root.selectedDevice?.id ? Theme.secondaryContainer : "transparent"

                            Behavior on color {
                                ColorAnimation { duration: Tokens.motion.duration.short4 }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: Tokens.spacing.medium
                                spacing: Tokens.spacing.medium

                                // Radio indicator
                                Rectangle {
                                    width: 20
                                    height: 20
                                    radius: 10
                                    color: "transparent"
                                    border.width: 2
                                    border.color: device.id === root.selectedDevice?.id ? Theme.primary : Theme.outline

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 10
                                        height: 10
                                        radius: 5
                                        color: Theme.primary
                                        visible: device.id === root.selectedDevice?.id
                                    }

                                    Behavior on border.color {
                                        ColorAnimation { duration: Tokens.motion.duration.short4 }
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
                                    fontSize: Tokens.typography.titleMedium.size
                                    iconColor: Theme.primary
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
                EmptyState {
                    visible: root.devices.length === 0
                    Layout.fillWidth: true
                    Layout.preferredHeight: 120

                    iconName: root.deviceType === "output" ? "speaker_notes_off" : "mic_off"
                    title: "No devices available"
                    iconContainerSize: 64
                    iconSize: 40
                }
            }

            // Cancel button
            MaterialButton {
                Layout.fillWidth: true
                text: "Cancel"
                variant: "text"
                onClicked: root.close()
            }
        }
}
