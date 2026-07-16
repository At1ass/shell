import QtQuick
import Quickshell
import QtQuick.Layouts
import qs.src.ui.containers
import qs.src.ui.base
import qs.src.core.config
import qs.src.core.services

MaterialCard {
    color: Theme.surfaceContainerHigh
    radius: Tokens.shape.large

    RowLayout {
        anchors.fill: parent
        anchors.margins: Tokens.spacing.medium
        spacing: Tokens.spacing.medium

        CircleAvatar {
                customSize: 100
                imageSource: "file://" + Quickshell.env("HOME") + "/.face"
                fallbackIcon: "person"
                fallbackText: SystemMonitorService.userName || "User"
                Layout.alignment: Qt.AlignHCenter
            }

        ColumnLayout {
            spacing: Tokens.spacing.small
            Layout.fillWidth: true
            Layout.fillHeight: true

            MaterialText {
                text: SystemMonitorService.userName || "User"
                textStyle: "titleLarge"
                colorRole: "onSurface"
                font.weight: Font.Bold
                Layout.alignment: Qt.AlignHCenter
            }

            // OS + WM
            RowLayout {
                spacing: Tokens.spacing.small

                MaterialIcon {
                    iconName: "computer"
                    fontSize: Tokens.typography.titleMedium.size
                    iconColor: Theme.primary
                    backgroundColor: "transparent"
                }

                MaterialText {
                    text: SystemMonitorService.osName + " • " + SystemMonitorService.wmName
                    textStyle: "bodyLarge"
                    colorRole: "onSurface"
                }
            }

            // Uptime
            RowLayout {
                spacing: Tokens.spacing.small

                MaterialIcon {
                    iconName: "schedule"
                    fontSize: Tokens.typography.titleMedium.size
                    iconColor: Theme.primary
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
