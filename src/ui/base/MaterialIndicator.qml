import QtQuick
import qs.src.core.config

Rectangle {
    id: root

    property string size: "small"        // extraSmall, small, medium, large, extraLarge
    property string colorRole: "outline" // any color from Theme
    property bool animated: true
    property string shape: "circle"      // circle, rounded, square

    // Sizes per Material Design
    readonly property var sizes: ({
        "extraSmall": 4,
        "small": 8,
        "medium": 12,
        "large": 16,
        "extraLarge": 20
    })

    // Automatic sizing
    width: sizes[size] || sizes.small
    height: width

    // Automatic radius depending on shape
    radius: {
        switch(shape) {
            case "circle": return width / 2
            case "rounded": return Tokens.shape.extraSmall
            case "square": return 0
            default: return width / 2
        }
    }

    // Automatic color from tokens
    color: Theme[colorRole] || Theme.outline

    // Animations
    Behavior on width {
        enabled: root.animated
        MotionAnimation {
            duration: Tokens.motion.duration.short2
            curve: "standard"
        }
    }

    // NO Behavior on height: `height: width` is a binding, so animating width
    // already animates height through it. A second Behavior chased the
    // already-animated value and left the dot elliptical mid-transition.

    Behavior on color {
        enabled: root.animated
        MotionColorAnimation {
            duration: Tokens.motion.duration.medium2
            curve: "standard"
        }
    }

    // Size validation
    onSizeChanged: {
        if (!sizes[size]) {
            console.warn(`MaterialIndicator: unknown size "${size}", falling back to small`)
        }
    }
}