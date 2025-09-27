import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components.base

ColumnLayout {
    id: root

    anchors.fill: parent
    spacing: Config.spacing.medium

    // Display settings section
    Rectangle {
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

    // System settings section
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 140
        color: Config.colors.surfaceContainerHigh
        radius: Config.shape.medium

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Config.spacing.medium
            spacing: Config.spacing.small

            MaterialText {
                text: "System Settings"
                textStyle: "titleSmall"
                colorRole: "surfaceText"
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                rowSpacing: Config.spacing.small
                columnSpacing: Config.spacing.medium

                // Night Light toggle
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    color: Config.colors.secondaryContainer
                    radius: Config.shape.small

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Config.spacing.small
                        spacing: Config.spacing.small

                        MaterialIcon {
                            iconName: "moon"
                            iconStyle: "bold"
                            iconSize: 16
                            color: "transparent"
                            iconColor: Config.colors.surfaceText
                            radius: 0
                            enableRipple: false
                        }
                        MaterialText {
                            text: "Night Light"
                            textStyle: "labelMedium"
                            colorRole: "secondaryContainerText"
                            Layout.fillWidth: true
                        }
                        MaterialText {
                            text: "ON"
                            textStyle: "labelSmall"
                            colorRole: "secondaryContainerText"
                        }
                    }
                }

                // Auto rotate
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    color: Config.colors.surface
                    radius: Config.shape.small
                    border.width: 1
                    border.color: Config.colors.outline

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Config.spacing.small
                        spacing: Config.spacing.small

                        MaterialIcon {
                            iconName: "device-rotate"
                            iconStyle: "bold"
                            iconSize: 16
                            color: "transparent"
                            iconColor: Config.colors.surfaceText
                            radius: 0
                            enableRipple: false
                        }
                        MaterialText {
                            text: "Auto Rotate"
                            textStyle: "labelMedium"
                            colorRole: "surfaceText"
                            Layout.fillWidth: true
                        }
                        MaterialText {
                            text: "OFF"
                            textStyle: "labelSmall"
                            colorRole: "surfaceVariantText"
                        }
                    }
                }

                // Color profile
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    color: Config.colors.surface
                    radius: Config.shape.small
                    border.width: 1
                    border.color: Config.colors.outline

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Config.spacing.small
                        spacing: Config.spacing.small

                        MaterialIcon {
                            iconName: "palette"
                            iconStyle: "bold"
                            iconSize: 16
                            color: "transparent"
                            iconColor: Config.colors.surfaceText
                            radius: 0
                            enableRipple: false
                        }
                        MaterialText {
                            text: "sRGB"
                            textStyle: "labelMedium"
                            colorRole: "surfaceText"
                            Layout.fillWidth: true
                        }
                    }
                }

                // Scaling
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    color: Config.colors.surface
                    radius: Config.shape.small
                    border.width: 1
                    border.color: Config.colors.outline

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Config.spacing.small
                        spacing: Config.spacing.small

                        MaterialIcon {
                            iconName: "magnifying-glass"
                            iconStyle: "bold"
                            iconSize: 16
                            color: "transparent"
                            iconColor: Config.colors.surfaceText
                            radius: 0
                            enableRipple: false
                        }
                        MaterialText {
                            text: "100% Scale"
                            textStyle: "labelMedium"
                            colorRole: "surfaceText"
                            Layout.fillWidth: true
                        }
                    }
                }
            }
        }
    }

    // Power management section
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 140
        color: Config.colors.surfaceContainerHigh
        radius: Config.shape.medium

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Config.spacing.medium
            spacing: Config.spacing.small

            MaterialText {
                text: "Power Management"
                textStyle: "titleSmall"
                colorRole: "surfaceText"
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Config.spacing.medium

                // Battery info (if applicable)
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 60
                    color: Config.colors.tertiaryContainer
                    radius: Config.shape.small

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Config.spacing.small
                        spacing: Config.spacing.small

                        MaterialIcon {
                            iconName: "battery-full"
                            iconStyle: "bold"
                            iconSize: 24
                            color: "transparent"
                            iconColor: Config.colors.surfaceText
                            radius: 0
                            enableRipple: false
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            MaterialText {
                                text: "AC Power"
                                textStyle: "labelMedium"
                                colorRole: "tertiaryContainerText"
                            }
                            MaterialText {
                                text: "Plugged In"
                                textStyle: "labelSmall"
                                colorRole: "tertiaryContainerText"
                            }
                        }
                    }
                }

                // Power actions
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Config.spacing.small

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        color: Config.colors.surface
                        radius: Config.shape.small
                        border.width: 1
                        border.color: Config.colors.outline

                        MaterialText {
                            anchors.centerIn: parent
                            text: "Suspend"
                            textStyle: "labelSmall"
                            colorRole: "surfaceText"
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        color: Config.colors.surface
                        radius: Config.shape.small
                        border.width: 1
                        border.color: Config.colors.outline

                        MaterialText {
                            anchors.centerIn: parent
                            text: "Restart"
                            textStyle: "labelSmall"
                            colorRole: "surfaceText"
                        }
                    }
                }
            }
        }
    }

    // System information section
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
                text: "System Information"
                textStyle: "titleSmall"
                colorRole: "surfaceText"
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Config.spacing.medium

                // ASCII Logo
                MaterialText {
                    text: `      /\\
     /  \\
    /\\   \\
   /  \\  /\\
  /    \\/  \\
 /\\        /\\
/__\\      /  \\
   \\      \\  /
    \\____\\_/`
                    textStyle: "bodySmall"
                    colorRole: "primary"
                    font.family: "monospace"
                    Layout.alignment: Qt.AlignTop
                    Layout.preferredWidth: 100
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Config.spacing.extraSmall

                // Username@hostname
                MaterialText {
                    text: "at1ass@at1ass"
                    textStyle: "titleSmall"
                    colorRole: "surfaceText"
                    font.weight: Font.Medium
                }

                // Separator line
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Config.colors.outline
                    Layout.bottomMargin: Config.spacing.small
                }

                // OS
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Config.spacing.medium

                    MaterialText {
                        text: "OS"
                        textStyle: "labelMedium"
                        colorRole: "surfaceVariantText"
                        Layout.preferredWidth: 80
                    }
                    MaterialText {
                        text: "Arch Linux x86_64"
                        textStyle: "labelMedium"
                        colorRole: "surfaceText"
                        Layout.fillWidth: true
                    }
                }

                // Kernel
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Config.spacing.medium

                    MaterialText {
                        text: "Kernel"
                        textStyle: "labelMedium"
                        colorRole: "surfaceVariantText"
                        Layout.preferredWidth: 80
                    }
                    MaterialText {
                        text: "Linux 6.16.8-arch3-1"
                        textStyle: "labelMedium"
                        colorRole: "surfaceText"
                        Layout.fillWidth: true
                    }
                }

                // WM
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Config.spacing.medium

                    MaterialText {
                        text: "WM"
                        textStyle: "labelMedium"
                        colorRole: "surfaceVariantText"
                        Layout.preferredWidth: 80
                    }
                    MaterialText {
                        text: "Hyprland (Wayland)"
                        textStyle: "labelMedium"
                        colorRole: "surfaceText"
                        Layout.fillWidth: true
                    }
                }

                // CPU
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Config.spacing.medium

                    MaterialText {
                        text: "CPU"
                        textStyle: "labelMedium"
                        colorRole: "surfaceVariantText"
                        Layout.preferredWidth: 80
                    }
                    MaterialText {
                        text: "AMD Ryzen 7 7700X (16) @ 5.58 GHz"
                        textStyle: "labelMedium"
                        colorRole: "surfaceText"
                        Layout.fillWidth: true
                    }
                }

                // Memory
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Config.spacing.medium

                    MaterialText {
                        text: "Memory"
                        textStyle: "labelMedium"
                        colorRole: "surfaceVariantText"
                        Layout.preferredWidth: 80
                    }
                    MaterialText {
                        text: "11.29 GiB / 30.94 GiB (36%)"
                        textStyle: "labelMedium"
                        colorRole: "surfaceText"
                        Layout.fillWidth: true
                    }
                }

                // Disk
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Config.spacing.medium

                    MaterialText {
                        text: "Disk (/)"
                        textStyle: "labelMedium"
                        colorRole: "surfaceVariantText"
                        Layout.preferredWidth: 80
                    }
                    MaterialText {
                        text: "38.64 GiB / 931.01 GiB (4%)"
                        textStyle: "labelMedium"
                        colorRole: "surfaceText"
                        Layout.fillWidth: true
                    }
                }
                }
            }
        }
    }
}