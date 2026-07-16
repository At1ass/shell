import QtQuick
import qs.src.core.config

// Optimized Material Design 3 Icon component
// Removed: ripple effects, OpacityMask, layer.enabled for better performance
Rectangle {
    id: root

    property string iconName: ""
    readonly property string fontFamily: "Material Symbols Rounded"
    property int fontSize: Tokens.typography.bodyLarge.size
    property real fill: enabled ? 1 : 0
    property int grade: 0
    property real sizePadding: 1.2  // Multiplier for auto-sizing (fontSize * sizePadding)

    // Color properties
    property color backgroundColor: "transparent"
    property color iconColor: enabled ? Theme.primary : Theme.onSurfaceVariant

    // Auto-size based on fontSize with padding (can be overridden by setting width/height explicitly)
    implicitWidth: fontSize * sizePadding
    implicitHeight: fontSize * sizePadding
    radius: Math.min(width, height) / 2

    color: backgroundColor

    // Color transitions
    Behavior on color {
        ColorAnimation {
            duration: Tokens.motion.duration.short3
            easing.type: Tokens.motion.easing.standard
            easing.bezierCurve: Tokens.motion.easing.standardPoints
        }
    }

    // Icon text using optimized MaterialText
    MaterialText {
        id: icon
        anchors.centerIn: parent
        text: root.iconName
        color: root.iconColor
        font.family: root.fontFamily
        font.pixelSize: root.fontSize
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
