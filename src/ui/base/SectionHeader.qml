import QtQuick
import QtQuick.Layouts
import qs.src.core.config
import qs.src.ui.base

// Material Design 3 Section Header
RowLayout {
    id: root

    property string title: ""
    property string icon: ""
    property color iconColor: Theme.primary

    // Badge properties
    property string badgeText: ""
    property color badgeBackground: Theme.primaryContainer
    property color badgeTextColor: Theme.onPrimaryContainer

    // Trailing content slot
    property alias trailingContent: trailingSlot.data

    spacing: Tokens.spacing.small

    // Leading icon
    MaterialIcon {
        visible: root.icon !== ""
        iconName: root.icon
        fontSize: Tokens.iconSize.large
        iconColor: root.iconColor
        backgroundColor: "transparent"
    }

    // Title text
    MaterialText {
        text: root.title
        textStyle: "titleLarge"
        colorRole: "onSurface"
        font.weight: Font.Medium
    }

    // Spacer
    Item {
        Layout.fillWidth: true
    }

    // Badge (if specified)
    Rectangle {
        visible: root.badgeText !== ""
        implicitWidth: badgeLabel.width + Tokens.spacing.medium
        implicitHeight: 24
        radius: 12
        color: root.badgeBackground

        MaterialText {
            id: badgeLabel
            anchors.centerIn: parent
            text: root.badgeText
            textStyle: "labelMedium"
            color: root.badgeTextColor
            font.weight: Font.Bold
        }
    }

    // Trailing content slot
    Item {
        id: trailingSlot
        Layout.preferredWidth: childrenRect.width
        Layout.preferredHeight: childrenRect.height
    }
}
