import QtQuick
import QtQuick.Layouts
import qs.src.core.config
import qs.src.ui.base
import qs.src.ui.feedback

// A labelled on/off tile.
//
// State is carried on TWO axes, fill and outline, rather than fill alone. Under
// a pack with no shadow and one surface tier the outline is the only structural
// device there is, and leaving it constant meant an inactive control had nothing
// to say for itself -- the quick actions distinguished on/off by icon tint and
// nothing else.
//
// The label is not optional. The panel this replaces used icon-only buttons with
// a hover tooltip, so what a toggle did was learned by memory or by waiting.
Item {
    id: root

    property string iconName: ""
    property string label: ""
    property bool active: false
    property bool showLabel: true

    signal clicked()

    implicitWidth: Math.max(96, row.implicitWidth + Tokens.spacing.small * 2)
    implicitHeight: Math.max(Tokens.touchTarget.minimum * 0.84, row.implicitHeight + Tokens.spacing.small)

    Rectangle {
        id: surface
        anchors.fill: parent
        radius: Tokens.shape.small
        color: root.active ? Qt.alpha(Theme.primary, Tokens.stateLayer.pressedOpacity * 1.4)
                           : "transparent"
        border.width: Math.max(1, Tokens.border.width)
        // Not derived from the hover opacity: at the minimal pack's 0.05 that
        // produced a 0.10 outline, which on screen was no outline at all -- half
        // the tiles read as floating labels. An inactive tile still has to be a
        // tile.
        border.color: root.active ? Theme.primary : Qt.alpha(Theme.onSurface, 0.28)

        Behavior on color {
            MotionColorAnimation {
                duration: Tokens.motion.duration.short4
                curve: "standard"
            }
        }

        Behavior on border.color {
            MotionColorAnimation {
                duration: Tokens.motion.duration.short4
                curve: "standard"
            }
        }

        StateLayer {
            target: surface
            hovered: mouse.containsMouse
            pressed: mouse.pressed
        }

        RowLayout {
            id: row
            anchors.fill: parent
            anchors.leftMargin: Tokens.spacing.small
            anchors.rightMargin: Tokens.spacing.small
            spacing: Tokens.spacing.small

            MaterialIcon {
                iconName: root.iconName
                fontSize: Tokens.iconSize.medium
                backgroundColor: "transparent"
                iconColor: root.active ? Theme.primary : Theme.onSurfaceVariant
            }

            MaterialText {
                Layout.fillWidth: true
                visible: root.showLabel && root.label !== ""
                text: root.label
                textStyle: "labelMedium"
                colorRole: root.active ? "onSurface" : "onSurfaceVariant"
                elide: Text.ElideRight
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
