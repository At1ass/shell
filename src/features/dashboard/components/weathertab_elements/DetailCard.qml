import QtQuick
import QtQuick.Layouts
import qs.src.ui.containers
import qs.src.ui.base
import qs.src.core.config

// Compact detail card for weather info (similar to caelesia)
MaterialCard {
    id: root

    property string iconName
    property string label
    property string value
    property color iconColor: Config.colors.primary

    Layout.preferredHeight: 70
    color: Qt.alpha(Config.colors.surfaceContainerHigh, 0.80)
    radius: Config.shape.medium

    RowLayout {
        anchors.centerIn: parent
        spacing: Config.spacing.medium

        // Icon
        MaterialIcon {
            iconName: root.iconName
            fontSize: Config.typography.headlineMedium.size
            iconColor: root.iconColor
            backgroundColor: "transparent"
            Layout.alignment: Qt.AlignVCenter
        }

        // Label + Value
        ColumnLayout {
            spacing: 0
            Layout.alignment: Qt.AlignVCenter

            MaterialText {
                text: root.label
                textStyle: "bodySmall"
                colorRole: "onSurfaceVariant"
            }

            MaterialText {
                text: root.value
                textStyle: "titleMedium"
                colorRole: "onSurface"
                font.weight: Font.Bold
            }
        }
    }
}
