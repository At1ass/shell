import QtQuick
import qs.src.core.config
import qs.src.ui.base
import qs.src.ui.feedback

// Material Design 3 Checkbox (controlled: parent owns `checked`, reacts to `toggled`).
Item {
    id: root

    property bool checked: false

    signal toggled(bool checked)

    // 18dp box inside a 40dp interactive target.
    readonly property int boxSize: 18
    implicitWidth: 40
    implicitHeight: 40

    opacity: enabled ? 1.0 : Tokens.state.disabledContentOpacity

    Rectangle {
        id: box
        anchors.centerIn: parent
        width: root.boxSize
        height: root.boxSize
        radius: Tokens.shape.extraSmall
        color: root.checked ? Theme.primary : "transparent"
        border.width: root.checked ? 0 : 2
        border.color: Theme.onSurfaceVariant

        Behavior on color {
            MotionColorAnimation {
                duration: Tokens.motion.duration.short3
                curve: "standard"
            }
        }

        MaterialIcon {
            anchors.centerIn: parent
            visible: root.checked
            iconName: "check"
            fontSize: Tokens.iconSize.small
            iconColor: Theme.onPrimary
            backgroundColor: "transparent"
        }
    }

    // 40dp circular state-layer halo (MD3)
    Rectangle {
        id: ripple
        anchors.centerIn: parent
        width: 40
        height: 40
        radius: 20
        color: "transparent"

        StateLayer {
            target: ripple
            layerColor: Theme.onSurface
            hovered: mouseArea.containsMouse
            pressed: mouseArea.pressed
            focused: root.activeFocus
            showFocusRing: root.activeFocus
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.checked)
    }

    // Keyboard operation. The kit shipped focus-ring tokens (Tokens.focusRing)
    // and a StateLayer that could draw them, but nothing that could ever take
    // focus — so the ring was unreachable infrastructure. Space and Enter
    // mirror a click, matching MD3 and every toolkit's button contract.
    activeFocusOnTab: root.enabled
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Space || event.key === Qt.Key_Return
            || event.key === Qt.Key_Enter) {
            if (root.enabled && !event.isAutoRepeat) root.toggled(!root.checked)
            event.accepted = true
        }
    }
}
