import QtQuick
import QtQuick.Layouts
import qs.src.core.config
import qs.src.ui.base

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
        Rectangle {
            visible: root.toggleEnabled
            width: 36
            height: 20
            radius: 10
            color: root.toggleChecked ? Theme.primary : Theme.surfaceContainerHighest
            border.width: root.toggleChecked ? 0 : 2
            border.color: Theme.outline

            Behavior on color {
                ColorAnimation { duration: Tokens.motion.duration.short4 }
            }

            Rectangle {
                y: (parent.height - height) / 2
                x: root.toggleChecked ? parent.width - width - 3 : 3
                width: root.toggleChecked ? 14 : 12
                height: width
                radius: width / 2
                color: root.toggleChecked ? Theme.onPrimary : Theme.outline

                Behavior on x {
                    NumberAnimation {
                        duration: Tokens.motion.duration.short4
                        easing.type: Tokens.motion.easing.emphasizedDecelerate
                    }
                }
                Behavior on width {
                    NumberAnimation { duration: Tokens.motion.duration.short4 }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleClicked()
            }
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
