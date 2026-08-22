pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs.src.core.config
import qs.src.ui.base

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

    // A pack that separates surfaces with an outline instead of a shadow turns this
    // on everywhere; MD3 leaves it off and separates with tone and shadow. Setting
    // it explicitly still wins under either pack.
    property bool outlined: Tokens.border.width > 0
    // Derived, not picked: see Theme.outlineOn. The palette moves with the wallpaper,
    // so a fixed role is a line that disappears on some of them.
    property color outlineColor: Theme.outlineOn(root.color, Tokens.border.minContrast)

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
    //
    // Behind a Loader because elevation 0 is the DEFAULT here and on MaterialCard:
    // an unconditional MultiEffect meant every flat card in the shell carried a
    // blur-capable scene-graph node for a shadow it would never draw, delegates
    // in every list included.
    Loader {
        active: root._hasShadow
        anchors.fill: surfaceRect
        z: -1

        sourceComponent: MultiEffect {
            source: surfaceRect
            shadowEnabled: true
            shadowColor: Qt.alpha(Theme.shadow, root._level.shadowOpacity)
            blurMax: 64
            shadowBlur: Math.min(1.0, root._level.shadowRadius / 64)
            shadowVerticalOffset: root._level.shadowVerticalOffset
            shadowHorizontalOffset: 0
            autoPaddingEnabled: true
        }
    }

    Rectangle {
        id: surfaceRect
        anchors.fill: parent
        radius: root.radius
        color: root.color
        // An explicit `outlined: true` draws even under a pack whose border width
        // is 0, which is what that property meant before packs existed.
        border.width: root.outlined ? Math.max(1, Tokens.border.width) : 0
        border.color: root.outlined ? root.outlineColor : "transparent"

        Behavior on color {
            MotionColorAnimation {
                duration: Tokens.motion.duration.short4
                curve: "standard"
            }
        }
    }

    // Children render above the surface fill.
    Item {
        id: contentArea
        anchors.fill: parent
    }
}
