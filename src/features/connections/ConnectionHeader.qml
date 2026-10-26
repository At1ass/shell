import QtQuick
import qs.src.core.config
import qs.src.ui.base
import qs.src.ui.containers
import qs.src.ui.inputs

ListItem {
    id: root
    property bool expanded: false
    property bool toggleVisible: false
    property bool toggleChecked: false
    property bool toggleAvailable: true
    signal toggleRequested()

    margin: Tokens.spacing.small
    radius: Tokens.shape.small
    color: expanded ? Theme.surfaceContainerHigh : "transparent"
    trailingContent: Row {
        spacing: Tokens.spacing.small
        MaterialSwitch {
            visible: root.toggleVisible
            enabled: root.toggleAvailable
            checked: root.toggleChecked
            Accessible.name: root.headline
            onToggled: root.toggleRequested()
        }
        MaterialIcon {
            anchors.verticalCenter: parent.verticalCenter
            iconName: root.expanded ? "expand_less" : "expand_more"
            fontSize: Tokens.iconSize.medium
            backgroundColor: "transparent"
        }
    }
}
