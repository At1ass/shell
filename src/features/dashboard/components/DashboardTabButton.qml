import QtQuick
import qs.src.ui.base
import qs.src.core.config

// A dashboard tab: its name, and a rule under the current one.
//
// It used to be a 96px-wide icon over a label, five of them across a 92px bar --
// 22% of the panel's height spent on navigation, in a panel whose whole content
// is four rows tall. The icons were decoration too: nobody identifies the weather
// tab by a cloud when the word "Weather" is under it.
Item {
    id: tabBtn

    property bool isActive: false
    property string label: "Tab"

    signal clicked()

    implicitWidth: labelText.implicitWidth
    implicitHeight: labelText.implicitHeight + Tokens.spacing.extraSmall + rule.height

    MaterialText {
        id: labelText
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        text: tabBtn.label
        textStyle: "labelLarge"
        colorRole: tabBtn.isActive ? "onSurface" : "onSurfaceVariant"

        Behavior on color {
            MotionColorAnimation {
                duration: Tokens.motion.duration.short4
                curve: "standard"
            }
        }
    }

    // The only accent in the header. It marks one thing, which is what makes it
    // readable at a glance.
    Rectangle {
        id: rule
        anchors.top: labelText.bottom
        anchors.topMargin: Tokens.spacing.extraSmall
        anchors.horizontalCenter: parent.horizontalCenter
        width: labelText.implicitWidth
        height: 2
        color: Theme.primary
        opacity: tabBtn.isActive ? 1 : 0

        Behavior on opacity {
            MotionAnimation {
                duration: Tokens.motion.duration.medium2
                curve: "emphasizedDecelerate"
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        anchors.margins: -Tokens.spacing.small
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: tabBtn.clicked()
    }
}
