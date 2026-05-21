import QtQuick
import qs.src.core.config
import qs.src.ui.base

// Material Design 3 Switch (controlled: parent owns `checked`, reacts to `toggled`).
Item {
    id: root

    property bool checked: false
    property bool enabled: true
    // Optional check glyph inside the thumb when on.
    property bool showCheckIcon: false

    signal toggled(bool checked)

    implicitWidth: 52
    implicitHeight: 32

    opacity: enabled ? 1.0 : Tokens.state.disabledContentOpacity

    Rectangle {
        id: track
        anchors.fill: parent
        radius: Tokens.shape.large
        color: root.checked ? Theme.primary : Theme.surfaceContainerHighest
        border.width: root.checked ? 0 : 2
        border.color: Theme.outline

        Behavior on color {
            ColorAnimation {
                duration: Tokens.motion.duration.short4
                easing.type: Tokens.motion.easing.standard
                easing.bezierCurve: Tokens.motion.easing.standardPoints
            }
        }

        Rectangle {
            id: thumb
            x: root.checked ? parent.width - width - 6 : 6
            anchors.verticalCenter: parent.verticalCenter
            width: root.checked ? 24 : 16
            height: width
            radius: width / 2
            color: root.checked ? Theme.onPrimary : Theme.outline

            Behavior on x {
                NumberAnimation {
                    duration: Tokens.motion.duration.short4
                    easing.type: Tokens.motion.easing.emphasizedDecelerate
                    easing.bezierCurve: Tokens.motion.easing.emphasizedDeceleratePoints
                }
            }
            Behavior on width { NumberAnimation { duration: Tokens.motion.duration.short4 } }
            Behavior on color { ColorAnimation { duration: Tokens.motion.duration.short4 } }

            MaterialIcon {
                anchors.centerIn: parent
                visible: root.showCheckIcon && root.checked
                iconName: "check"
                fontSize: Tokens.iconSize.small
                iconColor: Theme.onPrimaryContainer
                backgroundColor: "transparent"
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.checked)
    }
}
