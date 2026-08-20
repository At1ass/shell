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

    // Color. Prefer the ROLE form — it is what makes the component themeable
    // without the call site importing Theme:
    //
    //     MaterialIcon { colorRole: "onSurfaceVariant" }      // preferred
    //     MaterialIcon { iconColor: someComputedColor }       // escape hatch
    //
    // MaterialText has taken a role since it was written; this one only took a
    // raw color, so a label and the icon beside it were always spelled
    // differently and every icon dragged `Theme.` into the feature. Setting
    // `iconColor` still wins, for the cases that genuinely compute a colour.
    property string colorRole: ""
    property color backgroundColor: "transparent"
    property color iconColor: colorRole !== ""
                              ? (Theme[colorRole] ?? Theme.onSurface)
                              : (enabled ? Theme.primary : Theme.onSurfaceVariant)

    // Auto-size based on fontSize with padding (can be overridden by setting
    // width/height explicitly). ROUNDED: fontSize is already round(N * fontScale),
    // so multiplying by 1.2 lands on fractions for every token — 16.8, 21.6,
    // 34.8, 37.2 px at the default scale. Fractional item geometry puts the
    // glyph on a half-pixel and costs sharpness for nothing.
    implicitWidth: Math.round(fontSize * sizePadding)
    implicitHeight: Math.round(fontSize * sizePadding)
    radius: Math.min(width, height) / 2

    color: backgroundColor

    // Color transitions
    Behavior on color {
        MotionColorAnimation {
            duration: Tokens.motion.duration.short3
            curve: "standard"
        }
    }

    // Icon text using optimized MaterialText
    MaterialText {
        id: icon
        anchors.centerIn: parent
        text: root.iconName
        color: root.iconColor
        font.family: root.fontFamily
        // LOAD-BEARING — see the note in MaterialText. Material Symbols is a
        // variable font and Qt's distance-field renderer corrupts its glyphs;
        // this puts icons back on the direct rasteriser while body text keeps
        // subpixel positioning. Removing this line breaks every icon that
        // swaps its glyph on a live item (toast level, DND bell, chevrons,
        // volume, battery, play/pause).
        renderType: Text.NativeRendering
        font.pixelSize: root.fontSize
        textFormat: Text.PlainText
        font.variableAxes: ({
            FILL: root.fill,
            GRAD: root.grade,
            opsz: Math.min(Math.max(root.fontSize, 20), 48),
            wght: 400
        })

        Behavior on color {
            MotionColorAnimation {
                duration: Tokens.motion.duration.short4
                curve: "standard"
            }
        }
    }
}
