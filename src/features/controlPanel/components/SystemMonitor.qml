import QtQuick
import QtQuick.Layouts
import qs.src.ui.containers
import qs.src.ui.inputs
import qs.src.ui.feedback
import qs.src.core.config
import qs.src.ui.base

Rectangle {
    id: root

    Layout.fillWidth: true
    Layout.preferredHeight: 180
    color: Config.colors.surfaceContainerHigh
    radius: Config.shape.medium

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Config.spacing.medium
        spacing: Config.spacing.small

        MaterialText {
            text: "System Monitor"
            textStyle: "titleSmall"
            colorRole: "surfaceText"
        }

        // First row: CPU, RAM, CPU Temp
        RowLayout {
            Layout.fillWidth: true
            spacing: Config.spacing.small

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                color: Config.colors.primaryContainer
                radius: Config.shape.small

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 2

                    MaterialText {
                        text: "CPU"
                        textStyle: "labelSmall"
                        colorRole: "primaryContainerText"
                        Layout.alignment: Qt.AlignHCenter
                    }
                    MaterialText {
                        text: "45%"
                        textStyle: "labelLarge"
                        colorRole: "primaryContainerText"
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                color: Config.colors.secondaryContainer
                radius: Config.shape.small

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 2

                    MaterialText {
                        text: "RAM"
                        textStyle: "labelSmall"
                        colorRole: "secondaryContainerText"
                        Layout.alignment: Qt.AlignHCenter
                    }
                    MaterialText {
                        text: "8.2GB"
                        textStyle: "labelLarge"
                        colorRole: "secondaryContainerText"
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                color: Config.colors.tertiaryContainer
                radius: Config.shape.small

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 2

                    MaterialText {
                        text: "CPU °C"
                        textStyle: "labelSmall"
                        colorRole: "tertiaryContainerText"
                        Layout.alignment: Qt.AlignHCenter
                    }
                    MaterialText {
                        text: "62°"
                        textStyle: "labelLarge"
                        colorRole: "tertiaryContainerText"
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }
        }

        // Second row: GPU, Disk, GPU Temp
        RowLayout {
            Layout.fillWidth: true
            spacing: Config.spacing.small

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                color: Config.colors.primaryContainer
                radius: Config.shape.small

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 2

                    MaterialText {
                        text: "GPU"
                        textStyle: "labelSmall"
                        colorRole: "primaryContainerText"
                        Layout.alignment: Qt.AlignHCenter
                    }
                    MaterialText {
                        text: "78%"
                        textStyle: "labelLarge"
                        colorRole: "primaryContainerText"
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                color: Config.colors.secondaryContainer
                radius: Config.shape.small

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 2

                    MaterialText {
                        text: "DISK"
                        textStyle: "labelSmall"
                        colorRole: "secondaryContainerText"
                        Layout.alignment: Qt.AlignHCenter
                    }
                    MaterialText {
                        text: "156GB"
                        textStyle: "labelLarge"
                        colorRole: "secondaryContainerText"
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                color: Config.colors.tertiaryContainer
                radius: Config.shape.small

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 2

                    MaterialText {
                        text: "GPU °C"
                        textStyle: "labelSmall"
                        colorRole: "tertiaryContainerText"
                        Layout.alignment: Qt.AlignHCenter
                    }
                    MaterialText {
                        text: "71°"
                        textStyle: "labelLarge"
                        colorRole: "tertiaryContainerText"
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }
        }
    }
}