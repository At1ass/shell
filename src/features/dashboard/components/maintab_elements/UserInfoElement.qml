import QtQuick
import QtQuick.Layouts
import qs.src.ui.containers
import qs.src.ui.base
import qs.src.core.config
import qs.src.core.services

MaterialCard {
    color: Config.colors.surfaceContainerHigh
    radius: Config.shape.large

    RowLayout {
        anchors.fill: parent
        anchors.margins: Config.spacing.medium
        spacing: Config.spacing.medium

        // Avatar + Username
        ColumnLayout {
            spacing: Config.spacing.small
            Layout.alignment: Qt.AlignTop

            CircleAvatar {
                customSize: 100
                imageSource: "file:///home/at1ass/.face"
                fallbackIcon: "person"
                fallbackText: SystemMonitorService.userName || "User"
                Layout.alignment: Qt.AlignHCenter
            }

            MaterialText {
                text: SystemMonitorService.userName || "User"
                textStyle: "titleLarge"
                colorRole: "onSurface"
                font.weight: Font.Bold
                Layout.alignment: Qt.AlignHCenter
            }
        }

        // System Info
        ColumnLayout {
            spacing: Config.spacing.small
            Layout.fillWidth: true
            Layout.fillHeight: true

            // OS + WM
            RowLayout {
                spacing: Config.spacing.small

                MaterialIcon {
                    iconName: "computer"
                    fontSize: Config.typography.titleMedium.size
                    iconColor: Config.colors.primary
                    backgroundColor: "transparent"
                }

                MaterialText {
                    text: SystemMonitorService.osName + " • " + SystemMonitorService.wmName
                    textStyle: "bodyLarge"
                    colorRole: "onSurface"
                }
            }

            // CPU
            RowLayout {
                spacing: Config.spacing.small

                MaterialIcon {
                    iconName: "developer_board"
                    fontSize: Config.typography.titleMedium.size
                    iconColor: Config.colors.primary
                    backgroundColor: "transparent"
                }

                MaterialText {
                    text: SystemMonitorService.cpuModel || "CPU"
                    textStyle: "bodyLarge"
                    colorRole: "onSurface"
                }
            }

            // GPU
            RowLayout {
                spacing: Config.spacing.small

                MaterialIcon {
                    iconName: "videogame_asset"
                    fontSize: Config.typography.titleMedium.size
                    iconColor: Config.colors.primary
                    backgroundColor: "transparent"
                }

                MaterialText {
                    text: SystemMonitorService.gpuModel || "GPU"
                    textStyle: "bodyLarge"
                    colorRole: "onSurface"
                }
            }

            // Uptime
            RowLayout {
                spacing: Config.spacing.small

                MaterialIcon {
                    iconName: "schedule"
                    fontSize: Config.typography.titleMedium.size
                    iconColor: Config.colors.primary
                    backgroundColor: "transparent"
                }

                MaterialText {
                    text: DateTime.uptime
                    textStyle: "bodyLarge"
                    colorRole: "onSurface"
                }
            }
        }
    }
}
