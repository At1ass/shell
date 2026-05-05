import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.src.core.config
import qs.src.core.services
import qs.src.ui.base
import qs.src.ui.containers
import qs.src.ui.feedback

Rectangle {
    id: root
    property string groupAppName: ""
    property string groupAppIcon: ""
    property int groupCount: 0
    property bool expanded: true

    signal toggleExpanded()

    implicitHeight: headerRow.implicitHeight + Tokens.spacing.small * 2
    color: "transparent"
    radius: Tokens.shape.small

    StateLayer {
        layerColor: Theme.onSurface
        hovered: headerMouseArea.containsMouse
        pressed: headerMouseArea.pressed
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
            Layout.preferredWidth: 20
            Layout.preferredHeight: 20
            fillMode: Image.PreserveAspectFit
            sourceSize.width: 20
            sourceSize.height: 20
            smooth: true
        }

        MaterialText {
            text: root.groupAppName
            textStyle: "labelLarge"
            colorRole: "onSurface"
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        // Count badge
        Rectangle {
            visible: root.groupCount > 1
            implicitWidth: Math.max(countLabel.implicitWidth + Tokens.spacing.small * 2, implicitHeight)
            implicitHeight: countLabel.implicitHeight + Tokens.spacing.extraSmall
            radius: Tokens.shape.full
            color: Theme.secondaryContainer

            MaterialText {
                id: countLabel
                anchors.centerIn: parent
                text: root.groupCount.toString()
                textStyle: "labelSmall"
                colorRole: "onSecondaryContainer"
            }
        }

        MaterialIcon {
            iconName: root.expanded ? "expand_less" : "expand_more"
            fontSize: Tokens.iconSize.medium
            iconColor: Theme.onSurfaceVariant
            backgroundColor: "transparent"
        }
    }
}
