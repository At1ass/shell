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
        color: mouseArea.containsMouse ? Config.colors.surfaceContainerHighest : Config.colors.surfaceContainerHigh
        radius: Config.shape.medium

        Behavior on color {
            ColorAnimation { duration: Config.motion.duration.short4 }
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: Config.spacing.medium
            spacing: Config.spacing.small

            // Selected item content (will be set by parent)
            Item {
                id: contentItem
                Layout.fillWidth: true
                Layout.fillHeight: true

                children: root.children.length > 1 ? [root.children[root.children.length - 1]] : []
            }

            MaterialIcon {
                iconName: root.open ? "expand_less" : "expand_more"
                fontSize: Config.typography.titleLarge.size
                iconColor: Config.colors.onSurfaceVariant
                backgroundColor: "transparent"

                Behavior on rotation {
                    NumberAnimation {
                        duration: Config.motion.duration.short4
                        easing.type: Config.motion.easing.emphasizedDecelerate
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
        radius: Config.shape.medium
        color: Config.colors.surfaceContainerHigh
        border.width: 1
        border.color: Config.colors.outlineVariant

        // M3 elevation через surface tint (вместо DropShadow)
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: parent.radius - 1
            color: Config.colors.primary
            opacity: 0.05
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Config.motion.duration.short4
                easing.type: Config.motion.easing.emphasizedDecelerate
            }
        }

        Behavior on y {
            NumberAnimation {
                duration: Config.motion.duration.short4
                easing.type: Config.motion.easing.emphasizedDecelerate
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
                    color: itemMouseArea.containsMouse ? Config.colors.surfaceContainerHighest :
                           modelData.value === root.selectedValue ? Config.colors.secondaryContainer : "transparent"
                    radius: Config.shape.small

                    Behavior on color {
                        ColorAnimation { duration: Config.motion.duration.short4 }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Config.spacing.medium
                        anchors.rightMargin: Config.spacing.medium
                        spacing: Config.spacing.small

                        MaterialIcon {
                            visible: modelData.icon !== undefined
                            iconName: modelData.icon || ""
                            fontSize: Config.typography.titleMedium.size
                            iconColor: modelData.value === root.selectedValue ? Config.colors.onSecondaryContainer : Config.colors.onSurfaceVariant
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
                            fontSize: Config.typography.titleMedium.size
                            iconColor: Config.colors.onSecondaryContainer
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
