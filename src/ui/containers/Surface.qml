import QtQuick
import QtQuick.Effects
import qs.src.core.config

// Material Design 3 elevated surface primitive.
//
// MD3 expresses elevation as a TONAL surface color (surfaceContainer tiers) PLUS,
// for floating elements, a subtle drop shadow. This component encapsulates both,
// driven by `Tokens.elevation`. Use it directly as a container, or assign it as the
// `background:` of a Pane/Control.
Item {
    id: root

    // Elevation level 0–5 (see Tokens.elevation). Controls shadow and, unless `color`
    // is overridden, the tonal surface role.
    property int elevation: 0
    property int radius: Tokens.shape.medium
    property bool outlined: false
    property color outlineColor: Theme.outlineVariant

    // Surface fill — defaults to the elevation level's tonal role; override freely.
    property color color: {
        const role = _level.surfaceRole
        return Theme[role] !== undefined ? Theme[role] : Theme.surface
    }

    default property alias content: contentArea.data

    readonly property var _level: Tokens.elevation.level(elevation)
    readonly property bool _hasShadow: elevation > 0 && _level.shadowOpacity > 0

    // Drop shadow: rendered from the surface shape and placed behind it. The effect also
    // re-draws the (identical) fill underneath the real surface — invisible overdraw — so
    // only the shadow halo shows. autoPadding keeps the blur from being clipped.
    MultiEffect {
        source: surfaceRect
        anchors.fill: surfaceRect
        z: -1
        visible: root._hasShadow
        shadowEnabled: root._hasShadow
        shadowColor: Qt.rgba(0, 0, 0, root._level.shadowOpacity)
        blurMax: 64
        shadowBlur: Math.min(1.0, root._level.shadowRadius / 64)
        shadowVerticalOffset: root._level.shadowVerticalOffset
        shadowHorizontalOffset: 0
        autoPaddingEnabled: true
    }

    Rectangle {
        id: surfaceRect
        anchors.fill: parent
        radius: root.radius
        color: root.color
        border.width: root.outlined ? 1 : 0
        border.color: root.outlined ? root.outlineColor : "transparent"

        Behavior on color {
            ColorAnimation {
                duration: Tokens.motion.duration.short4
                easing.type: Tokens.motion.easing.standard
                easing.bezierCurve: Tokens.motion.easing.standardPoints
            }
        }
    }

    // Children render above the surface fill.
    Item {
        id: contentArea
        anchors.fill: parent
    }
}
