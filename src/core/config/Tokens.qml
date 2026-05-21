pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    // Material Design 3 spacing (8px grid system)
    readonly property QtObject spacing: QtObject {
        readonly property int none: 0
        readonly property int extraSmall: 4
        readonly property int small: 8
        readonly property int medium: 16
        readonly property int large: 24
        readonly property int extraLarge: 32
        readonly property int huge: 40
        readonly property int extraHuge: 48
    }

    // Material Design 3 shape/radius tokens
    readonly property QtObject shape: QtObject {
        readonly property int none: 0
        readonly property int extraSmall: 4
        readonly property int small: 8
        readonly property int medium: 12
        readonly property int large: 16
        readonly property int extraLarge: 28
        readonly property int full: 999
        // MD3 buttons are pill-shaped (radius = height/2). A large value clamps
        // to min(w,h)/2 in Qt, yielding a pill at any button height.
        readonly property int button: 999
    }

    // Font scale (0.5–2.0, 1.0 = normal)
    property real fontScale: AppConfig.fontScale

    // Typography following Material Design 3 — sizes scaled by fontScale
    readonly property QtObject typography: QtObject {
        readonly property string fontFamily: "Roboto"

        // Display styles
        readonly property QtObject displayLarge: QtObject {
            readonly property int size: Math.round(57 * root.fontScale)
            readonly property int lineHeight: Math.round(64 * root.fontScale)
            readonly property int weight: Font.Light
            readonly property real letterSpacing: -0.25
        }
        readonly property QtObject displayMedium: QtObject {
            readonly property int size: Math.round(45 * root.fontScale)
            readonly property int lineHeight: Math.round(52 * root.fontScale)
            readonly property int weight: Font.Light
            readonly property real letterSpacing: 0
        }
        readonly property QtObject displaySmall: QtObject {
            readonly property int size: Math.round(36 * root.fontScale)
            readonly property int lineHeight: Math.round(44 * root.fontScale)
            readonly property int weight: Font.Normal
            readonly property real letterSpacing: 0
        }

        // Headline styles
        readonly property QtObject headlineLarge: QtObject {
            readonly property int size: Math.round(32 * root.fontScale)
            readonly property int lineHeight: Math.round(40 * root.fontScale)
            readonly property int weight: Font.Normal
            readonly property real letterSpacing: 0
        }
        readonly property QtObject headlineMedium: QtObject {
            readonly property int size: Math.round(28 * root.fontScale)
            readonly property int lineHeight: Math.round(36 * root.fontScale)
            readonly property int weight: Font.Normal
            readonly property real letterSpacing: 0
        }
        readonly property QtObject headlineSmall: QtObject {
            readonly property int size: Math.round(24 * root.fontScale)
            readonly property int lineHeight: Math.round(32 * root.fontScale)
            readonly property int weight: Font.Normal
            readonly property real letterSpacing: 0
        }

        // Title styles
        readonly property QtObject titleLarge: QtObject {
            readonly property int size: Math.round(22 * root.fontScale)
            readonly property int lineHeight: Math.round(28 * root.fontScale)
            readonly property int weight: Font.Normal
            readonly property real letterSpacing: 0
        }
        readonly property QtObject titleMedium: QtObject {
            readonly property int size: Math.round(16 * root.fontScale)
            readonly property int lineHeight: Math.round(24 * root.fontScale)
            readonly property int weight: Font.Medium
            readonly property real letterSpacing: 0.15
        }
        readonly property QtObject titleSmall: QtObject {
            readonly property int size: Math.round(14 * root.fontScale)
            readonly property int lineHeight: Math.round(20 * root.fontScale)
            readonly property int weight: Font.Medium
            readonly property real letterSpacing: 0.1
        }

        // Label styles
        readonly property QtObject labelLarge: QtObject {
            readonly property int size: Math.round(14 * root.fontScale)
            readonly property int lineHeight: Math.round(20 * root.fontScale)
            readonly property int weight: Font.Medium
            readonly property real letterSpacing: 0.1
        }
        readonly property QtObject labelMedium: QtObject {
            readonly property int size: Math.round(12 * root.fontScale)
            readonly property int lineHeight: Math.round(16 * root.fontScale)
            readonly property int weight: Font.Medium
            readonly property real letterSpacing: 0.5
        }
        readonly property QtObject labelSmall: QtObject {
            readonly property int size: Math.round(11 * root.fontScale)
            readonly property int lineHeight: Math.round(16 * root.fontScale)
            readonly property int weight: Font.Medium
            readonly property real letterSpacing: 0.5
        }

        // Body styles
        readonly property QtObject bodyLarge: QtObject {
            readonly property int size: Math.round(16 * root.fontScale)
            readonly property int lineHeight: Math.round(24 * root.fontScale)
            readonly property int weight: Font.Normal
            readonly property real letterSpacing: 0.15
        }
        readonly property QtObject bodyMedium: QtObject {
            readonly property int size: Math.round(14 * root.fontScale)
            readonly property int lineHeight: Math.round(20 * root.fontScale)
            readonly property int weight: Font.Normal
            readonly property real letterSpacing: 0.25
        }
        readonly property QtObject bodySmall: QtObject {
            readonly property int size: Math.round(12 * root.fontScale)
            readonly property int lineHeight: Math.round(16 * root.fontScale)
            readonly property int weight: Font.Normal
            readonly property real letterSpacing: 0.4
        }
    }

    // Animation duration scale (0 = instant, 1 = normal)
    property real durationScale: 1.0

    // Material Motion specification
    readonly property QtObject motion: QtObject {
        // Duration tokens (milliseconds) — scaled by durationScale
        readonly property QtObject duration: QtObject {
            readonly property int short1: Math.round(50 * root.durationScale)
            readonly property int short2: Math.round(100 * root.durationScale)
            readonly property int short3: Math.round(150 * root.durationScale)
            readonly property int short4: Math.round(200 * root.durationScale)
            readonly property int medium1: Math.round(250 * root.durationScale)
            readonly property int medium2: Math.round(300 * root.durationScale)
            readonly property int medium3: Math.round(350 * root.durationScale)
            readonly property int medium4: Math.round(400 * root.durationScale)
            readonly property int long1: Math.round(450 * root.durationScale)
            readonly property int long2: Math.round(500 * root.durationScale)
            readonly property int long3: Math.round(550 * root.durationScale)
            readonly property int long4: Math.round(600 * root.durationScale)
            readonly property int extraLong1: Math.round(700 * root.durationScale)
            readonly property int extraLong2: Math.round(800 * root.durationScale)
            readonly property int extraLong3: Math.round(900 * root.durationScale)
            readonly property int extraLong4: Math.round(1000 * root.durationScale)
        }

        // Easing curves (Material Design 3)
        // Usage: enter/appear ⇒ emphasizedDecelerate, exit/disappear ⇒ emphasizedAccelerate,
        // persistent on-screen state changes ⇒ standard. `emphasized` is a single-curve
        // approximation (MD3's true emphasized is a two-part spring not expressible as one
        // cubic-bezier) — prefer the decelerate/accelerate variants for directional motion.
        readonly property QtObject easing: QtObject {
            readonly property int emphasized: Easing.BezierSpline
            readonly property var emphasizedPoints: [0.2, 0.0, 0, 1.0]
            readonly property int standard: Easing.BezierSpline
            readonly property var standardPoints: [0.2, 0.0, 0, 1.0]
            readonly property int emphasizedDecelerate: Easing.BezierSpline
            readonly property var emphasizedDeceleratePoints: [0.05, 0.7, 0.1, 1.0]
            readonly property int emphasizedAccelerate: Easing.BezierSpline
            readonly property var emphasizedAcceleratePoints: [0.3, 0.0, 0.8, 0.15]
        }
    }

    // Material Design 3 state layer opacity tokens
    readonly property QtObject stateLayer: QtObject {
        readonly property real hoverOpacity: 0.08
        readonly property real pressedOpacity: 0.12
        readonly property real focusOpacity: 0.12
        readonly property real draggedOpacity: 0.16
    }

    // Material Design 3 disabled state tokens (replaces ad-hoc Qt.alpha hacks)
    readonly property QtObject state: QtObject {
        readonly property real disabledContainerOpacity: 0.12
        readonly property real disabledContentOpacity: 0.38
    }

    // Keyboard focus indicator (MD3 focus ring)
    readonly property QtObject focusRing: QtObject {
        readonly property int width: 3
        readonly property int offset: 2
    }

    // Material Design 3 elevation tokens.
    // MD3 expresses elevation as a TONAL surface color (surfaceContainer tiers) PLUS,
    // for floating elements, a subtle shadow. Each level maps to a Theme color-role name
    // (resolve via Theme[level.surfaceRole]) and shadow params in px (consumed by Surface.qml,
    // which translates shadowRadius → MultiEffect blur).
    readonly property QtObject elevation: QtObject {
        readonly property QtObject level0: QtObject {
            readonly property string surfaceRole: "surface"
            readonly property int shadowRadius: 0
            readonly property int shadowVerticalOffset: 0
            readonly property real shadowOpacity: 0.0
        }
        readonly property QtObject level1: QtObject {
            readonly property string surfaceRole: "surfaceContainerLow"
            readonly property int shadowRadius: 3
            readonly property int shadowVerticalOffset: 1
            readonly property real shadowOpacity: 0.10
        }
        readonly property QtObject level2: QtObject {
            readonly property string surfaceRole: "surfaceContainer"
            readonly property int shadowRadius: 6
            readonly property int shadowVerticalOffset: 2
            readonly property real shadowOpacity: 0.12
        }
        readonly property QtObject level3: QtObject {
            readonly property string surfaceRole: "surfaceContainerHigh"
            readonly property int shadowRadius: 12
            readonly property int shadowVerticalOffset: 4
            readonly property real shadowOpacity: 0.14
        }
        readonly property QtObject level4: QtObject {
            readonly property string surfaceRole: "surfaceContainerHigh"
            readonly property int shadowRadius: 16
            readonly property int shadowVerticalOffset: 6
            readonly property real shadowOpacity: 0.16
        }
        readonly property QtObject level5: QtObject {
            readonly property string surfaceRole: "surfaceContainerHighest"
            readonly property int shadowRadius: 24
            readonly property int shadowVerticalOffset: 8
            readonly property real shadowOpacity: 0.18
        }

        // Resolve a level QtObject by integer (0–5); clamps out-of-range.
        function level(n) {
            switch (Math.max(0, Math.min(5, n))) {
            case 1: return level1
            case 2: return level2
            case 3: return level3
            case 4: return level4
            case 5: return level5
            default: return level0
            }
        }
    }

    // Material Design 3 icon size tokens
    readonly property QtObject iconSize: QtObject {
        readonly property int small: 16
        readonly property int medium: 20
        readonly property int large: 24
        readonly property int extraLarge: 32
    }

    // Material Design 3 touch target tokens
    readonly property QtObject touchTarget: QtObject {
        readonly property int minimum: 48
    }
}
