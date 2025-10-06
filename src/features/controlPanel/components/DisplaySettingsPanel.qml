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
            colorRole: "onSurface"
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
                        iconName: "light_mode"
                        color: "transparent"
                        iconColor: Config.colors.onSurface
                        radius: 0
                        enableRipple: false
                    }

                    MaterialText {
                        text: "Brightness"
                        textStyle: "labelMedium"
                        colorRole: "onSurface"
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
                    colorRole: "onSurfaceVariant"
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
                        color: "transparent"
                        iconColor: Config.colors.onSurface
                        radius: 0
                        enableRipple: false
                    }

                    MaterialText {
                        text: "Monitor"
                        textStyle: "labelMedium"
                        colorRole: "onSurface"
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
                        colorRole: "onPrimaryContainer"
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
                        colorRole: "onSurface"
                    }
                }
            }
        }
    }
}
