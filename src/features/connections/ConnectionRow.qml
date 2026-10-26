import QtQuick
import qs.src.core.config
import qs.src.ui.base
import qs.src.ui.containers

ListItem {
    id: root
    property bool busy: false
    property string badgeIcon: ""
    property bool hasOptions: true
    signal optionsRequested()

    margin: Tokens.spacing.small
    radius: Tokens.shape.small
    clickable: !busy
    trailingContent: Row {
        spacing: Tokens.spacing.extraSmall
        MaterialIcon {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.badgeIcon !== ""
            iconName: root.badgeIcon
            fontSize: Tokens.iconSize.small
            iconColor: Theme.onSurfaceVariant
            backgroundColor: "transparent"
        }
        IconButton {
            iconName: root.busy ? "pending" : "more_horiz"
            iconSize: Tokens.iconSize.medium
            Accessible.name: "Actions for " + root.headline
            visible: root.hasOptions
            onClicked: root.optionsRequested()
        }
    }
}
