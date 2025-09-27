import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components.base

Rectangle {
    id: root

    Layout.fillWidth: true
    Layout.preferredHeight: 120
    color: Config.colors.surfaceContainerHigh
    radius: Config.shape.medium

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Config.spacing.medium
        spacing: Config.spacing.small

        RowLayout {
            Layout.fillWidth: true

            MaterialText {
                text: "Audio Devices"
                textStyle: "titleSmall"
                colorRole: "surfaceText"
            }

            Item { Layout.fillWidth: true }

            MaterialIcon {
                iconName: "gear"
                iconStyle: "bold"
                iconSize: 16
                color: "transparent"
                iconColor: Config.colors.surfaceText
                radius: 0
                enableRipple: false
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Config.spacing.small

            // Output device
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                color: Config.colors.primaryContainer
                radius: Config.shape.small

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Config.spacing.small
                    spacing: Config.spacing.small

                    MaterialIcon {
                        iconName: "headphones"
                        iconStyle: "bold"
                        iconSize: 18
                        color: "transparent"
                        iconColor: Config.colors.surfaceText
                        radius: 0
                        enableRipple: false
                    }
                    MaterialText {
                        text: "Headphones (Active)"
                        textStyle: "labelMedium"
                        colorRole: "primaryContainerText"
                        Layout.fillWidth: true
                    }
                }
            }

            // Input device
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                color: Config.colors.surface
                radius: Config.shape.small
                border.width: 1
                border.color: Config.colors.outline

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Config.spacing.small
                    spacing: Config.spacing.small

                    MaterialIcon {
                        iconName: "microphone"
                        iconStyle: "bold"
                        iconSize: 18
                        color: "transparent"
                        iconColor: Config.colors.surfaceText
                        radius: 0
                        enableRipple: false
                    }
                    MaterialText {
                        text: "Built-in Microphone"
                        textStyle: "labelMedium"
                        colorRole: "surfaceText"
                        Layout.fillWidth: true
                    }
                }
            }
        }
    }
}