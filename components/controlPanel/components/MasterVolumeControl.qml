import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components.base

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
            iconName: "speaker-simple-high"
            iconStyle: "bold"
            iconSize: 24
            color: "transparent"
            iconColor: Config.colors.surfaceText
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
                colorRole: "surfaceText"
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
            colorRole: "surfaceText"
            Layout.alignment: Qt.AlignVCenter
        }
    }
}