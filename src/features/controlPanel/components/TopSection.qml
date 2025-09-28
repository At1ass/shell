import QtQuick
import QtQuick.Layouts
import qs.src.ui.containers
import qs.src.ui.inputs
import qs.src.ui.feedback
import qs.src.core.config
import qs.src.ui.base
import qs.src.core.services
import ".." as Panel

Rectangle {
    id: root

    Layout.fillWidth: true
    Layout.preferredHeight: 140
    color: Config.colors.surfaceContainer
    radius: Config.shape.medium

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Config.spacing.medium
        spacing: Config.spacing.small

        // First row - Uptime (left) and Time+Date (right)
        RowLayout {
            Layout.fillWidth: true
            spacing: Config.spacing.medium

            MaterialText {
                text: "Uptime: " + DateTime.uptime
                textStyle: "bodyMedium"
                colorRole: "surfaceText"
                Layout.alignment: Qt.AlignTop
            }

            Item {
                Layout.fillWidth: true
            }

            ColumnLayout {
                spacing: Config.spacing.extraSmall
                Layout.alignment: Qt.AlignTop

                MaterialText {
                    text: DateTime.time
                    textStyle: "headlineSmall"
                    colorRole: "surfaceText"
                    font.weight: Font.Medium
                    horizontalAlignment: Text.AlignRight
                }

                MaterialText {
                    text: DateTime.date
                    textStyle: "bodySmall"
                    colorRole: "surfaceVariantText"
                    horizontalAlignment: Text.AlignRight
                }
            }
        }

        // Third row - Quick toggle buttons (centered, no label)
        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            spacing: Config.spacing.medium

            Panel.QuickToggle {
                toggleIcon: "wifi-high"
                toggled: true // TODO: Connect to Network service
                onClicked: {
                    toggled = !toggled;
                    console.log("WiFi toggled:", toggled);
                }
            }

            Panel.QuickToggle {
                toggleIcon: "bluetooth"
                toggled: false // TODO: Connect to Bluetooth service
                onClicked: {
                    toggled = !toggled;
                    console.log("Bluetooth toggled:", toggled);
                }
            }

            Panel.QuickToggle {
                toggleIcon: "bell-simple" // Do Not Disturb
                toggled: false // TODO: Connect to Notification service
                onClicked: {
                    toggled = !toggled;
                    console.log("DND toggled:", toggled);
                }
            }
        }
    }
}