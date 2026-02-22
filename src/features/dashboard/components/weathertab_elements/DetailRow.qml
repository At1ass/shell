import QtQuick
import QtQuick.Layouts
import qs.src.ui.base
import qs.src.core.config

RowLayout {
    id: row

    required property string iconName
    required property string label
    required property string value

    spacing: Config.spacing.small
    Layout.fillWidth: true

    MaterialIcon {
        iconName: row.iconName
        fontSize: Config.typography.titleMedium.size
        iconColor: Config.colors.primary
        backgroundColor: "transparent"
    }

    MaterialText {
        text: row.label
        textStyle: "bodyMedium"
        colorRole: "onSurfaceVariant"
        Layout.fillWidth: true
    }

    MaterialText {
        text: row.value
        textStyle: "bodyMedium"
        colorRole: "onSurface"
        font.weight: Font.Medium
    }
}
