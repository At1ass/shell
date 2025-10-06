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

    RowLayout {
        anchors.fill: parent
        anchors.margins: Config.spacing.medium
        spacing: Config.spacing.medium

        MaterialIcon {
            iconName: "volume_up"
            iconSize: Config.typography.titleMedium.size
            iconColor: Config.colors.onSurface
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
