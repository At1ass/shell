import QtQuick
import QtQuick.Layouts
import qs.src.core.config
import qs.src.ui.base
import qs.src.ui.feedback
import qs.src.ui.inputs

MaterialCard {
    id: section

    property string title: ""
    property string icon: ""
    property string statusText: ""
    property color statusColor: Theme.onSurfaceVariant
    property bool expanded: false
    property bool toggleEnabled: false
    property bool toggleChecked: false
    default property alias content: contentContainer.data

    signal toggleClicked()
    signal headerClicked()

    color: Theme.surfaceContainerHigh
    radius: Tokens.shape.large
    clip: true

    implicitHeight: headerRow.height + (expanded ? contentContainer.implicitHeight + contentContainer.Layout.bottomMargin : 0)

    Behavior on implicitHeight {
        NumberAnimation {
            duration: Tokens.motion.duration.medium2
            easing.type: Tokens.motion.easing.emphasizedDecelerate
            easing.bezierCurve: Tokens.motion.easing.emphasizedDeceleratePoints
        }
    }

    ColumnLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        // Header
        Rectangle {
            id: headerRow
            Layout.fillWidth: true
            height: 64
            color: "transparent"
            radius: section.radius

            // Background mouse area — z:0, sits UNDER the RowLayout
            MouseArea {
                id: headerMouseArea
                anchors.fill: parent
                z: 0
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: section.headerClicked()
            }

            StateLayer {
                target: headerRow
                layerColor: Theme.onSurface
                hovered: headerMouseArea.containsMouse
                pressed: headerMouseArea.pressed
            }

            RowLayout {
                z: 1
                anchors.fill: parent
                anchors.leftMargin: Tokens.spacing.medium
                anchors.rightMargin: Tokens.spacing.medium
                spacing: Tokens.spacing.medium

                // Icon circle
                Rectangle {
                    width: 40
                    height: 40
                    radius: Tokens.shape.full
                    color: Theme.primaryContainer

                    MaterialIcon {
                        anchors.centerIn: parent
                        iconName: section.icon
                        fontSize: Tokens.typography.titleMedium.size
                        iconColor: Theme.onPrimaryContainer
                        backgroundColor: "transparent"
                    }
                }

                // Title + status
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    MaterialText {
                        text: section.title
                        textStyle: "titleSmall"
                        colorRole: "onSurface"
                        font.weight: Font.Medium
                    }

                    MaterialText {
                        visible: section.statusText !== ""
                        text: section.statusText
                        textStyle: "bodySmall"
                        color: section.statusColor
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                // Toggle switch
                MaterialSwitch {
                    visible: section.toggleEnabled
                    checked: section.toggleChecked
                    onToggled: section.toggleClicked()
                }

                // Chevron
                MaterialIcon {
                    iconName: "expand_more"
                    fontSize: Tokens.iconSize.large
                    iconColor: Theme.onSurfaceVariant
                    backgroundColor: "transparent"
                    rotation: section.expanded ? 180 : 0

                    Behavior on rotation {
                        NumberAnimation {
                            duration: Tokens.motion.duration.short4
                            easing.type: Tokens.motion.easing.emphasizedDecelerate
                            easing.bezierCurve: Tokens.motion.easing.emphasizedDeceleratePoints
                        }
                    }
                }
            }
        }

        // Content (collapsible)
        ColumnLayout {
            id: contentContainer
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.spacing.medium
            Layout.rightMargin: Tokens.spacing.medium
            Layout.bottomMargin: section.expanded ? Tokens.spacing.medium : 0
            visible: section.expanded
            spacing: 0
        }
    }
}
