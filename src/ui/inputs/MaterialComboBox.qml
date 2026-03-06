import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.src.core.config
import qs.src.ui.base

// MD3 Exposed Dropdown Menu (ComboBox)
Item {
    id: root

    property var model: []
    property int currentIndex: 0
    property string currentText: {
        if (!model || model.length === 0) return ""
        return model[currentIndex] || ""
    }
    property string label: ""
    property bool open: false

    implicitHeight: 48
    implicitWidth: 200

    Layout.fillWidth: true

    // Trigger field
    Rectangle {
        id: field
        anchors.fill: parent
        radius: Tokens.shape.small
        color: fieldMouse.containsMouse ? Qt.alpha(Theme.onSurface, Tokens.stateLayer.hoverOpacity)
                                        : Theme.surfaceContainerHighest
        border.width: root.open ? 2 : 1
        border.color: root.open ? Theme.primary : Theme.outline

        Behavior on border.color {
            ColorAnimation { duration: Tokens.motion.duration.short4 }
        }
        Behavior on color {
            ColorAnimation { duration: Tokens.motion.duration.short4 }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Tokens.spacing.medium
            anchors.rightMargin: Tokens.spacing.small
            spacing: Tokens.spacing.small

            MaterialText {
                Layout.fillWidth: true
                text: root.currentText
                textStyle: "bodyLarge"
                colorRole: "onSurface"
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }

            MaterialIcon {
                iconName: root.open ? "arrow_drop_up" : "arrow_drop_down"
                fontSize: Tokens.iconSize.large
                iconColor: Theme.onSurfaceVariant
                backgroundColor: "transparent"
            }
        }

        MouseArea {
            id: fieldMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.open = !root.open
        }
    }

    // Label (floating)
    Rectangle {
        visible: root.label !== ""
        x: Tokens.spacing.small
        y: -height / 2
        width: labelText.implicitWidth + Tokens.spacing.small * 2
        height: labelText.implicitHeight
        color: Theme.surfaceContainerHighest
        radius: 2
        z: 1

        MaterialText {
            id: labelText
            anchors.centerIn: parent
            text: root.label
            textStyle: "labelSmall"
            colorRole: root.open ? "primary" : "onSurfaceVariant"
        }
    }

    // Popup dropdown — renders above clipping parents
    Popup {
        id: popup
        visible: root.open
        x: 0
        y: _openUpward ? -implicitHeight - 4 : root.height + 4
        width: root.width
        padding: 0
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        onClosed: root.open = false

        property bool _openUpward: {
            if (!root.open) return false
            const overlay = Overlay.overlay
            if (!overlay) return false
            const mapped = root.mapToItem(overlay, 0, root.height + 4)
            const spaceBelow = overlay.height - mapped.y
            return spaceBelow < popup.implicitHeight && mapped.y > spaceBelow
        }

        background: Rectangle {
            radius: Tokens.shape.small
            color: Theme.surfaceContainer
            border.width: 1
            border.color: Theme.outlineVariant

            // M3 elevation tint
            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: parent.radius - 1
                color: Theme.primary
                opacity: 0.08
            }
        }

        transformOrigin: popup._openUpward ? Item.Bottom : Item.Top

        enter: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Tokens.motion.duration.short4; easing.type: Tokens.motion.easing.emphasizedDecelerate }
                NumberAnimation { property: "scale"; from: 0.95; to: 1.0; duration: Tokens.motion.duration.short4; easing.type: Tokens.motion.easing.emphasizedDecelerate }
            }
        }
        exit: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Tokens.motion.duration.short3; easing.type: Tokens.motion.easing.emphasizedAccelerate }
            }
        }

        contentItem: Column {
            id: menuColumn
            width: popup.width
            topPadding: Tokens.spacing.extraSmall
            bottomPadding: Tokens.spacing.extraSmall

            Repeater {
                model: root.model

                delegate: Rectangle {
                    width: menuColumn.width
                    height: 44
                    color: itemMouse.containsMouse
                           ? Qt.alpha(Theme.onSurface, Tokens.stateLayer.hoverOpacity)
                           : index === root.currentIndex
                             ? Qt.alpha(Theme.secondaryContainer, 0.7)
                             : "transparent"

                    Behavior on color {
                        ColorAnimation { duration: Tokens.motion.duration.short3 }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Tokens.spacing.medium
                        anchors.rightMargin: Tokens.spacing.medium
                        spacing: Tokens.spacing.small

                        MaterialText {
                            Layout.fillWidth: true
                            text: modelData
                            textStyle: "bodyLarge"
                            colorRole: index === root.currentIndex ? "onSecondaryContainer" : "onSurface"
                            verticalAlignment: Text.AlignVCenter
                        }

                        MaterialIcon {
                            visible: index === root.currentIndex
                            iconName: "check"
                            fontSize: Tokens.iconSize.medium
                            iconColor: Theme.onSecondaryContainer
                            backgroundColor: "transparent"
                        }
                    }

                    MouseArea {
                        id: itemMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.currentIndex = index
                            root.open = false
                        }
                    }
                }
            }
        }
    }
}
