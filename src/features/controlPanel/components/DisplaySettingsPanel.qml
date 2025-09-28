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
    Layout.preferredHeight: 160
    color: Config.colors.surfaceContainerHigh
    radius: Config.shape.medium

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Config.spacing.medium
        spacing: Config.spacing.small

        MaterialText {
            text: "Display Settings"
            textStyle: "titleSmall"
            colorRole: "surfaceText"
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Config.spacing.medium

            // Brightness control
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Config.spacing.small

                RowLayout {
                    spacing: Config.spacing.small

                    MaterialIcon {
                        iconName: "sun"
                        iconStyle: "bold"
                        iconSize: 16
                        color: "transparent"
                        iconColor: Config.colors.surfaceText
                        radius: 0
                        enableRipple: false
                    }

                    MaterialText {
                        text: "Brightness"
                        textStyle: "labelMedium"
                        colorRole: "surfaceText"
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 8
                    color: Config.colors.outline
                    radius: 4

                    Rectangle {
                        width: parent.width * 0.75
                        height: parent.height
                        color: Config.colors.primary
                        radius: 4
                    }
                }

                MaterialText {
                    text: "75%"
                    textStyle: "labelSmall"
                    colorRole: "surfaceVariantText"
                    Layout.alignment: Qt.AlignHCenter
                }
            }

            Rectangle {
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                color: Config.colors.outline
            }

            // Resolution/Monitor
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Config.spacing.small

                RowLayout {
                    spacing: Config.spacing.small

                    MaterialIcon {
                        iconName: "monitor"
                        iconStyle: "bold"
                        iconSize: 16
                        color: "transparent"
                        iconColor: Config.colors.surfaceText
                        radius: 0
                        enableRipple: false
                    }

                    MaterialText {
                        text: "Monitor"
                        textStyle: "labelMedium"
                        colorRole: "surfaceText"
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    color: Config.colors.primaryContainer
                    radius: Config.shape.small

                    MaterialText {
                        anchors.centerIn: parent
                        text: "1920×1080 @ 60Hz"
                        textStyle: "labelSmall"
                        colorRole: "primaryContainerText"
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    color: Config.colors.surface
                    radius: Config.shape.small
                    border.width: 1
                    border.color: Config.colors.outline

                    MaterialText {
                        anchors.centerIn: parent
                        text: "2560×1440 @ 144Hz"
                        textStyle: "labelSmall"
                        colorRole: "surfaceText"
                    }
                }
            }
        }
    }
}