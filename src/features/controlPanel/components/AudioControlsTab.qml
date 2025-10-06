import QtQuick
import QtQuick.Layouts
import qs.src.ui.containers
import qs.src.ui.inputs
import qs.src.ui.feedback
import QtQuick.Controls
import qs.src.core.config
import qs.src.ui.base

ColumnLayout {
    id: root

    anchors.fill: parent
    spacing: Config.spacing.medium

    // Master volume section
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 80
        color: Config.colors.surfaceContainerHigh
        radius: Config.shape.medium

        RowLayout {
            anchors.fill: parent
            anchors.margins: Config.spacing.medium
            spacing: Config.spacing.medium

            MaterialIcon {
                iconName: "volume_up"
                iconColor: Config.colors.onSurface
                fontSize: Config.typography.titleLarge.size
                radius: 0
                enableRipple: false
                Layout.alignment: Qt.AlignVCenter
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Config.spacing.extraSmall

                MaterialText {
                    text: "Master Volume"
                    textStyle: "titleSmall"
                    colorRole: "onSurface"
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 6
                    color: Config.colors.outline
                    radius: 3

                    Rectangle {
                        width: parent.width * 0.65
                        height: parent.height
                        color: Config.colors.primary
                        radius: 3
                    }
                }
            }

            MaterialText {
                text: "65%"
                textStyle: "labelMedium"
                colorRole: "onSurface"
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }

    // Audio devices section
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 150
        color: Config.colors.surfaceContainerHigh
        radius: Config.shape.medium

        ColumnLayout {
            anchors.fill: parent
            // Layout.fillWidth: true
            // Layout.fillHeight: true
            anchors.margins: Config.spacing.medium
            spacing: Config.spacing.small

            RowLayout {
                Layout.fillWidth: true

                MaterialText {
                    text: "Audio Devices"
                    textStyle: "titleSmall"
                    colorRole: "onSurface"
                }

                Item { Layout.fillWidth: true }

                MaterialIcon {
                    iconName: "settings"
                    iconColor: Config.colors.onSurface
                    radius: 0
                    enableRipple: false
                }
            }

            Item { Layout.fillHeight: true }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Config.spacing.small

                // Output device
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    color: Config.colors.primaryContainer
                    radius: Config.shape.small

                    RowLayout {
                        // anchors.fill: parent
                        Layout.fillWidth: true
                        Layout.preferredHeight: 32
                        Layout.alignment: Qt.AlignVCenter
                        anchors.margins: Config.spacing.small
                        spacing: Config.spacing.small

                        MaterialIcon {
                            iconName: "headphones"
                            iconColor: Config.colors.onSurface
                            radius: 0
                            enableRipple: false
                        }
                        MaterialText {
                            text: "Headphones (Active)"
                            textStyle: "labelMedium"
                            colorRole: "onPrimaryContainer"
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
                        // anchors.fill: parent
                        Layout.fillWidth: true
                        Layout.preferredHeight: 32
                        Layout.alignment: Qt.AlignVCenter
                        anchors.margins: Config.spacing.small
                        spacing: Config.spacing.small

                        MaterialIcon {
                            iconName: "mic"
                            iconColor: Config.colors.onSurface
                            radius: 0
                            enableRipple: false
                        }
                        MaterialText {
                            text: "Built-in Microphone"
                            textStyle: "labelMedium"
                            colorRole: "onSurface"
                            Layout.fillWidth: true
                        }
                    }
                }
            }
        }
    }

    // App volume mixer
    Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        color: Config.colors.surfaceContainerHigh
        radius: Config.shape.medium

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Config.spacing.medium
            spacing: Config.spacing.small

            MaterialText {
                text: "App Volume Mixer"
                textStyle: "titleSmall"
                colorRole: "onSurface"
            }

            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                ColumnLayout {
                    width: parent.width
                    spacing: Config.spacing.small

                    Repeater {
                        model: ["Firefox", "Discord", "Spotify", "System Sounds"]

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 50
                            color: Config.colors.surface
                            radius: Config.shape.small

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: Config.spacing.small
                                spacing: Config.spacing.medium

                                Rectangle {
                                    Layout.preferredWidth: 24
                                    Layout.preferredHeight: 24
                                    color: Config.colors.primary
                                    radius: 4

                                    MaterialText {
                                        anchors.centerIn: parent
                                        text: modelData.charAt(0)
                                        textStyle: "labelSmall"
                                        colorRole: "onPrimary"
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    MaterialText {
                                        text: modelData
                                        textStyle: "labelMedium"
                                        colorRole: "onSurface"
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 4
                                        color: Config.colors.outline
                                        radius: 2

                                        Rectangle {
                                            width: parent.width * (0.3 + index * 0.2)
                                            height: parent.height
                                            color: Config.colors.secondary
                                            radius: 2
                                        }
                                    }
                                }

                                MaterialText {
                                    text: Math.round((30 + index * 20)) + "%"
                                    textStyle: "labelSmall"
                                    colorRole: "onSurfaceVariant"
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
