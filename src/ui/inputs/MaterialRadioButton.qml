import QtQuick
import qs.src.core.config
import qs.src.ui.base
import qs.src.ui.feedback

// Material Design 3 Radio Button (controlled: parent owns `checked`, reacts to `clicked`).
Item {
    id: root

    property bool checked: false

    signal clicked()

    implicitWidth: 40
    implicitHeight: 40

    opacity: enabled ? 1.0 : Tokens.state.disabledContentOpacity

    // Outer ring
    Rectangle {
        id: ring
        anchors.centerIn: parent
        width: 20
        height: 20
        radius: 10
        color: "transparent"
        border.width: 2
        border.color: root.checked ? Theme.primary : Theme.onSurfaceVariant

        Behavior on border.color {
            MotionColorAnimation {
                duration: Tokens.motion.duration.short3
                curve: "standard"
            }
        }

        // Inner dot
        Rectangle {
            anchors.centerIn: parent
            width: root.checked ? 10 : 0
            height: width
            radius: width / 2
            color: Theme.primary

            Behavior on width {
                MotionAnimation {
                    duration: Tokens.motion.duration.short3
                    curve: "emphasizedDecelerate"
                }
            }
        }
    }

    // 40dp circular state-layer halo
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
            showFocusRing: false
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
