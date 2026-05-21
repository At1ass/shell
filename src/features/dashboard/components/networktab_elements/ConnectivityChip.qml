import QtQuick
import QtQuick.Layouts
import qs.src.core.config
import qs.src.ui.base
import qs.src.ui.inputs

Rectangle {
    id: root

    property string icon: ""
    property string title: ""
    property string statusText: ""
    property bool active: false
    property bool toggleEnabled: false
    property bool toggleChecked: false
    property color statusColor: Theme.onSurfaceVariant

    signal clicked()
    signal toggleClicked()

    Layout.fillWidth: true
    implicitHeight: 52
    radius: Tokens.shape.medium
    color: active ? Theme.secondaryContainer
                  : chipMouse.containsMouse ? Qt.alpha(Theme.onSurface, Tokens.stateLayer.hoverOpacity)
                                            : Theme.surfaceContainerHigh

    Behavior on color {
        ColorAnimation { duration: Tokens.motion.duration.short4 }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Tokens.spacing.small
        anchors.rightMargin: Tokens.spacing.small
        spacing: Tokens.spacing.small

        MaterialIcon {
            iconName: root.icon
            fontSize: Tokens.iconSize.medium
            iconColor: root.active ? Theme.onSecondaryContainer : Theme.onSurfaceVariant
            backgroundColor: "transparent"
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            MaterialText {
                text: root.title
                textStyle: "labelMedium"
                colorRole: root.active ? "onSecondaryContainer" : "onSurface"
                font.weight: Font.Medium
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            MaterialText {
                text: root.statusText
                textStyle: "labelSmall"
                color: root.active ? Theme.onSecondaryContainer : root.statusColor
                elide: Text.ElideRight
                Layout.fillWidth: true
                opacity: 0.8
            }
        }

        // Toggle switch
        MaterialSwitch {
            visible: root.toggleEnabled
            checked: root.toggleChecked
            onToggled: root.toggleClicked()
        }
    }

    MouseArea {
        id: chipMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
        z: -1
    }
}
