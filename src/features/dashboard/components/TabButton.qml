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
            iconName: nameIcon
            fontSize: Tokens.typography.headlineMedium.size
            iconColor: isActive ? Theme.onPrimaryContainer : Theme.onSurfaceVariant
            backgroundColor: "transparent"
            fill: isActive ? 1 : 0
            Layout.alignment: Qt.AlignHCenter

            Behavior on iconColor {
                ColorAnimation {
                    duration: Tokens.motion.duration.short4
                    easing.type: Tokens.motion.easing.standard
                }
            }

            Behavior on fill {
                NumberAnimation {
                    duration: Tokens.motion.duration.short4
                    easing.type: Tokens.motion.easing.standard
                }
            }
        }

        MaterialText {
            text: label
            textStyle: "labelMedium"
            colorRole: isActive ? "onSurface" : "onSurfaceVariant"
            Layout.alignment: Qt.AlignHCenter
        }
    }

    // Индикатор активной вкладки
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width * 0.6
        height: 2
        radius: 1
        color: Theme.primary
        opacity: isActive ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Tokens.motion.duration.medium2
                easing.type: Tokens.motion.easing.emphasizedDecelerate
            }
        }
    }
}
