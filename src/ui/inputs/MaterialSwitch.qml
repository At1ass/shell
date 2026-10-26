import QtQuick
import qs.src.core.config
import qs.src.ui.feedback
import qs.src.ui.base

// Material Design 3 Switch (controlled: parent owns `checked`, reacts to `toggled`).
Item {
    id: root

    property bool checked: false
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
            MotionColorAnimation {
                duration: Tokens.motion.duration.short4
                curve: "standard"
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
                MotionAnimation {
                    duration: Tokens.motion.duration.short4
                    curve: "emphasizedDecelerate"
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

    StateLayer {
        target: track
        focused: root.activeFocus
        layerColor: Theme.onSurface
    }
    Accessible.role: Accessible.CheckBox
    Accessible.checked: root.checked
    Accessible.onToggleAction: if (root.enabled) root.toggled(!root.checked)

    // Keyboard operation. The kit shipped focus-ring tokens (Tokens.focusRing)
    // and a StateLayer that could draw them, but nothing that could ever take
    // focus — so the ring was unreachable infrastructure. Space and Enter
    // mirror a click, matching MD3 and every toolkit's button contract.
    activeFocusOnTab: root.enabled
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Space || event.key === Qt.Key_Return
            || event.key === Qt.Key_Enter) {
            root.toggled(!root.checked)
            event.accepted = true
        }
    }
}
