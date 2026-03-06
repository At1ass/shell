import QtQuick
import qs.config

Rectangle {
    id: root

    property string iconName: ""
    readonly property string fontFamily: "Material Symbols Rounded"
    property int fontSize: Tokens.typography.bodyLarge.size
    property bool enabled: true
    property real fill: enabled ? 1 : 0
    property int grade: 0
    property real sizePadding: 1.2

    property color backgroundColor: "transparent"
    property color iconColor: enabled ? GreeterTheme.primary : GreeterTheme.onSurfaceVariant

    implicitWidth: fontSize * sizePadding
    implicitHeight: fontSize * sizePadding
    radius: Math.min(width, height) / 2

    color: backgroundColor

    Behavior on color {
        ColorAnimation {
            duration: Tokens.motion.duration.short3
            easing.type: Tokens.motion.easing.standard
            easing.bezierCurve: Tokens.motion.easing.standardPoints
        }
    }

    MaterialText {
        id: icon
        anchors.centerIn: parent
        text: root.iconName
        color: root.iconColor
        font.family: root.fontFamily
        font.pointSize: root.fontSize
        textFormat: Text.PlainText
        font.variableAxes: ({
            FILL: root.fill,
            GRAD: root.grade,
            opsz: Math.min(Math.max(root.fontSize, 20), 48),
            wght: 400
        })

        Behavior on color {
            ColorAnimation {
                duration: Tokens.motion.duration.short4
                easing.type: Tokens.motion.easing.standard
                easing.bezierCurve: Tokens.motion.easing.standardPoints
            }
        }
    }
}
