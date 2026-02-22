import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.src.core.config
import qs.src.ui.base
import qs.src.ui.containers

// MD3 Menu component
Item {
    id: root

    property var items: []  // Array of {text: string, value: any, icon: string (optional)}
    property var selectedValue: null
    property bool open: false

    signal itemSelected(var value)

    width: parent.width
    height: menuButton.height
    clip: false

    // Trigger button
    MaterialCard {
        id: menuButton
        anchors.fill: parent
        color: mouseArea.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
        radius: Tokens.shape.medium

        Behavior on color {
            ColorAnimation { duration: Tokens.motion.duration.short4 }
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: Tokens.spacing.medium
            spacing: Tokens.spacing.small

            // Selected item content (will be set by parent)
            Item {
                id: contentItem
                Layout.fillWidth: true
                Layout.fillHeight: true

                children: root.children.length > 1 ? [root.children[root.children.length - 1]] : []
            }

            MaterialIcon {
                iconName: root.open ? "expand_less" : "expand_more"
                fontSize: Tokens.typography.titleLarge.size
                iconColor: Theme.onSurfaceVariant
                backgroundColor: "transparent"

                Behavior on rotation {
                    NumberAnimation {
                        duration: Tokens.motion.duration.short4
                        easing.type: Tokens.motion.easing.emphasizedDecelerate
                    }
                }
            }
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.open = !root.open
        }
    }

    // Dropdown menu
    Rectangle {
        id: dropdown
        visible: root.open
        opacity: root.open ? 1 : 0
        y: menuButton.height + 4
        width: parent.width
        height: menuContent.implicitHeight
        radius: Tokens.shape.medium
        color: Theme.surfaceContainerHigh
        border.width: 1
        border.color: Theme.outlineVariant

        // M3 elevation через surface tint (вместо DropShadow)
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: parent.radius - 1
            color: Theme.primary
            opacity: 0.05
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Tokens.motion.duration.short4
                easing.type: Tokens.motion.easing.emphasizedDecelerate
            }
        }

        Behavior on y {
            NumberAnimation {
                duration: Tokens.motion.duration.short4
                easing.type: Tokens.motion.easing.emphasizedDecelerate
            }
        }

        ColumnLayout {
            id: menuContent
            width: parent.width
            spacing: 0

            Repeater {
                model: root.items

                delegate: Rectangle {
                    Layout.fillWidth: true
                    height: 48
                    color: itemMouseArea.containsMouse ? Theme.surfaceContainerHighest :
                           modelData.value === root.selectedValue ? Theme.secondaryContainer : "transparent"
                    radius: Tokens.shape.small

                    Behavior on color {
                        ColorAnimation { duration: Tokens.motion.duration.short4 }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Tokens.spacing.medium
                        anchors.rightMargin: Tokens.spacing.medium
                        spacing: Tokens.spacing.small

                        MaterialIcon {
                            visible: modelData.icon !== undefined
                            iconName: modelData.icon || ""
                            fontSize: Tokens.typography.titleMedium.size
                            iconColor: modelData.value === root.selectedValue ? Theme.onSecondaryContainer : Theme.onSurfaceVariant
                            backgroundColor: "transparent"
                        }

                        MaterialText {
                            text: modelData.text
                            textStyle: "bodyLarge"
                            colorRole: modelData.value === root.selectedValue ? "onSecondaryContainer" : "onSurface"
                            Layout.fillWidth: true
                        }

                        MaterialIcon {
                            visible: modelData.value === root.selectedValue
                            iconName: "check"
                            fontSize: Tokens.typography.titleMedium.size
                            iconColor: Theme.onSecondaryContainer
                            backgroundColor: "transparent"
                        }
                    }

                    MouseArea {
                        id: itemMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.selectedValue = modelData.value
                            root.itemSelected(modelData.value)
                            root.open = false
                        }
                    }
                }
            }
        }
    }

    // Close menu when clicking outside
    MouseArea {
        visible: root.open
        anchors.fill: parent
        anchors.topMargin: -1000
        anchors.bottomMargin: -1000
        anchors.leftMargin: -1000
        anchors.rightMargin: -1000
        z: -1
        onClicked: root.open = false
    }
}
