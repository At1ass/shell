import QtQuick
import QtQuick.Layouts
import qs.src.ui.containers
import qs.src.ui.base
import qs.src.core.config

// Compact detail card for weather info (similar to caelestia)
MaterialCard {
    id: root

    property string iconName
    property string label
    property string value
    property color iconColor: Theme.primary

    implicitHeight: detailRow.implicitHeight + Tokens.spacing.medium * 2
    color: Theme.surfaceContainerHigh
    radius: Tokens.shape.medium

    RowLayout {
        id: detailRow
        anchors.fill: parent
        anchors.margins: Tokens.spacing.medium
        spacing: Tokens.spacing.medium

        // Icon
        MaterialIcon {
            iconName: root.iconName
            fontSize: Tokens.iconSize.large
            iconColor: root.iconColor
            backgroundColor: "transparent"
            Layout.alignment: Qt.AlignVCenter
        }

        // Label + Value
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Layout.alignment: Qt.AlignVCenter

            MaterialText {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: root.label
                textStyle: "bodySmall"
                colorRole: "onSurfaceVariant"
            }

            MaterialText {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                textFormat: Text.PlainText
                text: root.value
                textStyle: "titleMedium"
                colorRole: "onSurface"
                font.weight: Font.Bold
            }
        }
    }
}
