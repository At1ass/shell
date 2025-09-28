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
    Layout.preferredHeight: 80
    color: Config.colors.surfaceContainerHigh
    radius: Config.shape.medium

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Config.spacing.medium
        spacing: Config.spacing.small

        MaterialText {
            text: "System Tray"
            textStyle: "titleSmall"
            colorRole: "surfaceText"
        }

        // Tray apps row
        RowLayout {
            Layout.fillWidth: true
            spacing: Config.spacing.small

            Repeater {
                model: 6

                Rectangle {
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    color: Config.colors.surface
                    radius: Config.shape.small
                    border.width: 1
                    border.color: Config.colors.outline

                    MaterialIcon {
                        anchors.centerIn: parent
                        iconName: ["app-window", "folder", "speaker-simple-high", "globe", "chat", "gear"][index]
                        iconStyle: "bold"
                        iconSize: 18
                        color: "transparent"
                        iconColor: Config.colors.surfaceText
                        radius: 0
                        enableRipple: false
                    }
                }
            }

            Item {
                Layout.fillWidth: true
            }

            MaterialText {
                text: "+3"
                textStyle: "labelSmall"
                colorRole: "surfaceVariantText"
            }
        }
    }
}