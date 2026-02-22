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
    property color iconColor: Theme.primary

    Layout.preferredHeight: 70
    color: Qt.alpha(Theme.surfaceContainerHigh, 0.80)
    radius: Tokens.shape.medium

    RowLayout {
        anchors.centerIn: parent
        spacing: Tokens.spacing.medium

        // Icon
        MaterialIcon {
            iconName: root.iconName
            fontSize: Tokens.typography.headlineMedium.size
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
