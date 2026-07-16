pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

// Design tokens. Every group is a typed inline component (not a bare QtObject)
// so qmllint can verify member access — a typo in a token name is a lint error.
// Instances assign values to declared properties; they never redeclare them.
Singleton {
    id: root

    component SpacingTokens: QtObject {
        readonly property int none: 0
        readonly property int extraSmall: 4
        readonly property int small: 8
        readonly property int medium: 16
        readonly property int large: 24
        readonly property int extraLarge: 32
        readonly property int huge: 40
        readonly property int extraHuge: 48
    }

    component ShapeTokens: QtObject {
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

    component TypeStyle: QtObject {
        property int size
        property int lineHeight
        property int weight: Font.Normal
        property real letterSpacing: 0
    }

    component TypographyTokens: QtObject {
        readonly property string fontFamily: "Roboto"
        // Resolved by fontconfig; used via MonoText for code/IPC/keybind text.
        readonly property string monoFamily: "monospace"

        readonly property TypeStyle displayLarge: TypeStyle {
            size: Math.round(57 * root.fontScale)
            lineHeight: Math.round(64 * root.fontScale)
            weight: Font.Light
            letterSpacing: -0.25
        }
        readonly property TypeStyle displayMedium: TypeStyle {
            size: Math.round(45 * root.fontScale)
            lineHeight: Math.round(52 * root.fontScale)
            weight: Font.Light
        }
        readonly property TypeStyle displaySmall: TypeStyle {
            size: Math.round(36 * root.fontScale)
            lineHeight: Math.round(44 * root.fontScale)
        }

        readonly property TypeStyle headlineLarge: TypeStyle {
            size: Math.round(32 * root.fontScale)
            lineHeight: Math.round(40 * root.fontScale)
        }
        readonly property TypeStyle headlineMedium: TypeStyle {
            size: Math.round(28 * root.fontScale)
            lineHeight: Math.round(36 * root.fontScale)
        }
        readonly property TypeStyle headlineSmall: TypeStyle {
            size: Math.round(24 * root.fontScale)
            lineHeight: Math.round(32 * root.fontScale)
        }

        readonly property TypeStyle titleLarge: TypeStyle {
            size: Math.round(22 * root.fontScale)
            lineHeight: Math.round(28 * root.fontScale)
        }
        readonly property TypeStyle titleMedium: TypeStyle {
            size: Math.round(16 * root.fontScale)
            lineHeight: Math.round(24 * root.fontScale)
            weight: Font.Medium
            letterSpacing: 0.15
        }
        readonly property TypeStyle titleSmall: TypeStyle {
            size: Math.round(14 * root.fontScale)
            lineHeight: Math.round(20 * root.fontScale)
            weight: Font.Medium
            letterSpacing: 0.1
        }

        readonly property TypeStyle labelLarge: TypeStyle {
            size: Math.round(14 * root.fontScale)
            lineHeight: Math.round(20 * root.fontScale)
            weight: Font.Medium
            letterSpacing: 0.1
        }
        readonly property TypeStyle labelMedium: TypeStyle {
            size: Math.round(12 * root.fontScale)
            lineHeight: Math.round(16 * root.fontScale)
            weight: Font.Medium
            letterSpacing: 0.5
        }
        readonly property TypeStyle labelSmall: TypeStyle {
            size: Math.round(11 * root.fontScale)
            lineHeight: Math.round(16 * root.fontScale)
            weight: Font.Medium
            letterSpacing: 0.5
        }

        readonly property TypeStyle bodyLarge: TypeStyle {
            size: Math.round(16 * root.fontScale)
            lineHeight: Math.round(24 * root.fontScale)
            letterSpacing: 0.15
        }
        readonly property TypeStyle bodyMedium: TypeStyle {
            size: Math.round(14 * root.fontScale)
            lineHeight: Math.round(20 * root.fontScale)
            letterSpacing: 0.25
        }
        readonly property TypeStyle bodySmall: TypeStyle {
            size: Math.round(12 * root.fontScale)
            lineHeight: Math.round(16 * root.fontScale)
            letterSpacing: 0.4
        }
    }

    component DurationTokens: QtObject {
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
    component EasingTokens: QtObject {
        readonly property int emphasized: Easing.BezierSpline
        readonly property var emphasizedPoints: [0.2, 0.0, 0, 1.0]
        readonly property int standard: Easing.BezierSpline
        readonly property var standardPoints: [0.2, 0.0, 0, 1.0]
        readonly property int emphasizedDecelerate: Easing.BezierSpline
        readonly property var emphasizedDeceleratePoints: [0.05, 0.7, 0.1, 1.0]
        readonly property int emphasizedAccelerate: Easing.BezierSpline
        readonly property var emphasizedAcceleratePoints: [0.3, 0.0, 0.8, 0.15]
    }

    component MotionTokens: QtObject {
        readonly property DurationTokens duration: DurationTokens {}
        readonly property EasingTokens easing: EasingTokens {}
    }

    component StateLayerTokens: QtObject {
        readonly property real hoverOpacity: 0.08
        readonly property real pressedOpacity: 0.12
        readonly property real focusOpacity: 0.12
        readonly property real draggedOpacity: 0.16
    }

    component StateTokens: QtObject {
        readonly property real disabledContainerOpacity: 0.12
        readonly property real disabledContentOpacity: 0.38
        // MD3 scrim: black at 32% over content behind modal surfaces.
        readonly property real scrimOpacity: 0.32
    }

    component FocusRingTokens: QtObject {
        readonly property int width: 3
        readonly property int offset: 2
    }

    // MD3 expresses elevation as a TONAL surface color (surfaceContainer tiers) PLUS,
    // for floating elements, a subtle shadow. Each level maps to a Theme color-role name
    // (resolve via Theme[level.surfaceRole]) and shadow params in px (consumed by Surface.qml,
    // which translates shadowRadius → MultiEffect blur).
    component ElevationLevel: QtObject {
        property string surfaceRole: "surface"
        property int shadowRadius: 0
        property int shadowVerticalOffset: 0
        property real shadowOpacity: 0.0
        // Primary-tint opacity for TRANSLUCENT surfaces where the tonal
        // surfaceRole cannot apply (bar/dock over wallpaper). Values follow
        // the pre-tonal M3 elevation overlay scale.
        property real tintOpacity: 0.0
    }

    component ElevationTokens: QtObject {
        readonly property ElevationLevel level0: ElevationLevel {}
        readonly property ElevationLevel level1: ElevationLevel {
            surfaceRole: "surfaceContainerLow"
            shadowRadius: 3
            shadowVerticalOffset: 1
            shadowOpacity: 0.10
            tintOpacity: 0.05
        }
        readonly property ElevationLevel level2: ElevationLevel {
            surfaceRole: "surfaceContainer"
            shadowRadius: 6
            shadowVerticalOffset: 2
            shadowOpacity: 0.12
            tintOpacity: 0.08
        }
        readonly property ElevationLevel level3: ElevationLevel {
            surfaceRole: "surfaceContainerHigh"
            shadowRadius: 12
            shadowVerticalOffset: 4
            shadowOpacity: 0.14
            tintOpacity: 0.11
        }
        readonly property ElevationLevel level4: ElevationLevel {
            surfaceRole: "surfaceContainerHigh"
            shadowRadius: 16
            shadowVerticalOffset: 6
            shadowOpacity: 0.16
            tintOpacity: 0.12
        }
        readonly property ElevationLevel level5: ElevationLevel {
            surfaceRole: "surfaceContainerHighest"
            shadowRadius: 24
            shadowVerticalOffset: 8
            shadowOpacity: 0.18
            tintOpacity: 0.14
        }

        // Resolve a level by integer (0–5); clamps out-of-range.
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

    component IconSizeTokens: QtObject {
        readonly property int small: 16
        readonly property int medium: 20
        readonly property int large: 24
        readonly property int extraLarge: 32
    }

    component TouchTargetTokens: QtObject {
        readonly property int minimum: 48
    }

    // Font scale (0.5–2.0, 1.0 = normal)
    property real fontScale: AppConfig.fontScale

    // Animation duration scale (0 = instant, 1 = normal)
    property real durationScale: 1.0

    // Material Design 3 spacing (8px grid system)
    readonly property SpacingTokens spacing: SpacingTokens {}

    // Material Design 3 shape/radius tokens
    readonly property ShapeTokens shape: ShapeTokens {}

    // Typography following Material Design 3 — sizes scaled by fontScale
    readonly property TypographyTokens typography: TypographyTokens {}

    // Material Motion specification
    readonly property MotionTokens motion: MotionTokens {}

    // Material Design 3 state layer opacity tokens
    readonly property StateLayerTokens stateLayer: StateLayerTokens {}

    // Material Design 3 disabled state tokens
    readonly property StateTokens state: StateTokens {}

    // Keyboard focus indicator (MD3 focus ring)
    readonly property FocusRingTokens focusRing: FocusRingTokens {}

    // Material Design 3 elevation tokens
    readonly property ElevationTokens elevation: ElevationTokens {}

    // Material Design 3 icon size tokens
    readonly property IconSizeTokens iconSize: IconSizeTokens {}

    // Material Design 3 touch target tokens
    readonly property TouchTargetTokens touchTarget: TouchTargetTokens {}
}
