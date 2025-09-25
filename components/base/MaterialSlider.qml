import QtQuick
import QtQuick.Controls
import qs.config

Slider {
    id: control

    stepSize: 0.01
    from: 0.0
    to: 1.0

    implicitWidth: 200
    implicitHeight: 20

    background: Rectangle {
        x: control.leftPadding
        y: control.topPadding + control.availableHeight / 2 - height / 2
        implicitWidth: 200
        implicitHeight: 4
        width: control.availableWidth
        height: implicitHeight
        radius: 2
        color: Config.colors.surfaceContainerHighest

        Rectangle {
            width: control.visualPosition * parent.width
            height: parent.height
            color: Config.colors.primary
            radius: 2
        }
    }

    handle: Rectangle {
        x: control.leftPadding + control.visualPosition * (control.availableWidth - width)
        y: control.topPadding + control.availableHeight / 2 - height / 2
        implicitWidth: 20
        implicitHeight: 20
        radius: 10
        color: control.pressed ? Config.colors.primaryContainer : Config.colors.primary
        border.width: control.pressed ? 4 : 0
        border.color: Config.colors.primaryContainer

        Behavior on color {
            ColorAnimation { duration: 150 }
        }

        Behavior on border.width {
            NumberAnimation { duration: 150 }
        }

        Rectangle {
            anchors.centerIn: parent
            width: control.pressed ? 28 : (control.hovered ? 24 : 0)
            height: width
            radius: width / 2
            color: Config.colors.primary
            opacity: control.pressed ? 0.12 : (control.hovered ? 0.08 : 0)

            Behavior on width {
                NumberAnimation { duration: 150 }
            }

            Behavior on opacity {
                NumberAnimation { duration: 150 }
            }
        }
    }
}