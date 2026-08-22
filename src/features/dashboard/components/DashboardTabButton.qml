import QtQuick
import QtQuick.Layouts
import qs.src.ui.base
import qs.src.ui.feedback
import qs.src.core.config

Item {
    id: tabBtn

    property bool isActive: false
    property string nameIcon: "star"
    property string label: "Tab"

    signal clicked()

    Rectangle {
        anchors.fill: parent
        radius: Tokens.shape.small
        color: "transparent"

        StateLayer {
            hovered: mouseArea.containsMouse
            pressed: mouseArea.pressed
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tabBtn.clicked()
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: Tokens.spacing.extraSmall

        MaterialIcon {
            iconName: tabBtn.nameIcon
            fontSize: Tokens.typography.headlineMedium.size
            iconColor: tabBtn.isActive ? Theme.onPrimaryContainer : Theme.onSurfaceVariant
            backgroundColor: "transparent"
            fill: tabBtn.isActive ? 1 : 0
            Layout.alignment: Qt.AlignHCenter

            Behavior on iconColor {
                MotionColorAnimation {
                    duration: Tokens.motion.duration.short4
                    curve: "standard"
                }
            }

            Behavior on fill {
                MotionAnimation {
                    duration: Tokens.motion.duration.short4
                    curve: "standard"
                }
            }
        }

        MaterialText {
            text: tabBtn.label
            textStyle: "labelMedium"
            colorRole: tabBtn.isActive ? "onSurface" : "onSurfaceVariant"
            Layout.alignment: Qt.AlignHCenter
        }
    }

    // Active tab indicator
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width * 0.6
        height: 2
        radius: Tokens.shape.full
        color: Theme.primary
        opacity: tabBtn.isActive ? 1 : 0

        Behavior on opacity {
            MotionAnimation {
                duration: Tokens.motion.duration.medium2
                curve: "emphasizedDecelerate"
            }
        }
    }
}
