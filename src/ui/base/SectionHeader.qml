import QtQuick
import QtQuick.Layouts
import qs.src.core.config
import qs.src.ui.base
import qs.src.ui.feedback

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

    // Badge — from the kit. This was a hand-rolled Rectangle + MaterialText
    // pair inside the kit itself, duplicating a component two directories away.
    Badge {
        inline: true
        visible: root.badgeText !== ""
        text: root.badgeText
        badgeColor: root.badgeBackground
        textColor: root.badgeTextColor
    }

    // Trailing content slot
    Item {
        id: trailingSlot
        Layout.preferredWidth: childrenRect.width
        Layout.preferredHeight: childrenRect.height
    }
}
