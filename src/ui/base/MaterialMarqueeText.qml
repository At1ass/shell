pragma ComponentBehavior: Bound
import QtQuick
import qs.src.core.config

Item {
    id: root

    property string textStyle: "bodyMedium"
    property string colorRole: "onSurface"
    property string text: ""
    property var weight: Font.Normal
    property var align: Text.AlignLeft

    property int startDelay: 1200
    property int endDelay: 800
    property real speed: 30   // px/sec

    readonly property real baseX: overflow
    ? 0
    : (width - label.implicitWidth) / 2
    clip: true
    height: label.implicitHeight

    readonly property bool overflow: label.implicitWidth > width

    MaterialText {
        id: label
        text: root.text
        // horizontalAlignment: root.align
        visible: true
        textStyle: root.textStyle
        colorRole: root.colorRole
        font.weight: root.weight
        x: offset + root.baseX
    }

    property real offset: 0

    SequentialAnimation {
        id: anim
        running: root.overflow && Tokens.durationScale > 0
        loops: Animation.Infinite

        PauseAnimation {
            duration: root.startDelay
        }

        NumberAnimation {
            target: root
            property: "offset"
            from: 0
            to: root.width - label.implicitWidth
            duration: Math.abs(root.width - label.implicitWidth) / root.speed * 1000
            easing.type: Easing.InOutSine
        }

        PauseAnimation {
            duration: root.endDelay
        }

        NumberAnimation {
            target: root
            property: "offset"
            from: root.width - label.implicitWidth
            to: 0
            duration: Math.abs(root.width - label.implicitWidth) / root.speed * 1000
            easing.type: Easing.InOutSine
        }

        PauseAnimation {
            duration: root.startDelay
        }
    }

    // Reset if text changes
    onTextChanged: offset = 0
}
