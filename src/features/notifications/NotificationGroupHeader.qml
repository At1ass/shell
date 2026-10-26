pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.src.core.config
import qs.src.ui.base
import qs.src.ui.feedback

// Section header for one application's group in the notification centre.
// Root is a plain Item: the header has no fill of its own, so the Rectangle it
// used to be existed only to host a state layer that StateLayer already draws.
Item {
    id: root

    property string groupAppName: ""
    property string groupAppIcon: ""
    property int groupCount: 0
    property bool expanded: true
    property bool selected: false

    signal toggleExpanded()

    implicitHeight: headerRow.implicitHeight + Tokens.spacing.small * 2

    StateLayer {
        layerColor: Theme.onSurface
        hovered: headerMouseArea.containsMouse
        pressed: headerMouseArea.pressed
        focused: root.selected
        showFocusRing: root.selected
    }

    MouseArea {
        id: headerMouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggleExpanded()
    }

    RowLayout {
        id: headerRow
        anchors.fill: parent
        anchors.leftMargin: Tokens.spacing.medium
        anchors.rightMargin: Tokens.spacing.small
        anchors.topMargin: Tokens.spacing.small
        anchors.bottomMargin: Tokens.spacing.small
        spacing: Tokens.spacing.small

        Image {
            visible: source !== ""
            source: root.groupAppIcon ? Quickshell.iconPath(root.groupAppIcon) : ""
            Layout.preferredWidth: Tokens.iconSize.medium
            Layout.preferredHeight: Tokens.iconSize.medium
            fillMode: Image.PreserveAspectFit
            sourceSize.width: Tokens.iconSize.medium
            sourceSize.height: Tokens.iconSize.medium
            smooth: true
        }

        MaterialText {
            text: root.groupAppName
            textStyle: "labelLarge"
            colorRole: "onSurface"
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        Badge {
            inline: true
            visible: root.groupCount > 1
            text: root.groupCount.toString()
            badgeColor: Theme.secondaryContainer
            textColor: Theme.onSecondaryContainer
        }

        MaterialIcon {
            iconName: root.expanded ? "expand_less" : "expand_more"
            fontSize: Tokens.iconSize.medium
            iconColor: Theme.onSurfaceVariant
            backgroundColor: "transparent"
        }
    }
}
