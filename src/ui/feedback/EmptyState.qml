import QtQuick
import QtQuick.Layouts
import qs.src.core.config
import qs.src.ui.base

// Material Design 3 Empty State
Item {
    id: root

    property string iconName: "info"
    property string title: "No data"
    property string subtitle: ""
    property int iconContainerSize: 80
    property int iconSize: 48

    ColumnLayout {
        anchors.centerIn: parent
        spacing: Config.spacing.medium

        // Icon container (MD3 spec: 64-80dp circle)
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            width: root.iconContainerSize
            height: root.iconContainerSize
            radius: root.iconContainerSize / 2
            color: Config.colors.surfaceContainerHighest

            MaterialIcon {
                anchors.centerIn: parent
                iconName: root.iconName
                fontSize: root.iconSize
                iconColor: Config.colors.onSurfaceVariant
                backgroundColor: "transparent"
                opacity: 0.6
            }
        }

        MaterialText {
            visible: root.title !== ""
            Layout.alignment: Qt.AlignHCenter
            text: root.title
            textStyle: "titleMedium"
            colorRole: "onSurface"
            font.weight: Font.Medium
        }

        MaterialText {
            visible: root.subtitle !== ""
            Layout.alignment: Qt.AlignHCenter
            text: root.subtitle
            textStyle: "bodyMedium"
            colorRole: "onSurfaceVariant"
        }
    }
}
