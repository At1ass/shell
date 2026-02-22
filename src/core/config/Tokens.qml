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
    }

    // Typography following Material Design 3
    readonly property QtObject typography: QtObject {
        readonly property string fontFamily: "Roboto"

        // Display styles
        readonly property QtObject displayLarge: QtObject {
            readonly property int size: 57
            readonly property int lineHeight: 64
            readonly property int weight: Font.Light
            readonly property real letterSpacing: -0.25
        }
        readonly property QtObject displayMedium: QtObject {
            readonly property int size: 45
            readonly property int lineHeight: 52
            readonly property int weight: Font.Light
            readonly property real letterSpacing: 0
        }
        readonly property QtObject displaySmall: QtObject {
            readonly property int size: 36
            readonly property int lineHeight: 44
            readonly property int weight: Font.Normal
            readonly property real letterSpacing: 0
        }

        // Headline styles
        readonly property QtObject headlineLarge: QtObject {
            readonly property int size: 32
            readonly property int lineHeight: 40
            readonly property int weight: Font.Normal
            readonly property real letterSpacing: 0
        }
        readonly property QtObject headlineMedium: QtObject {
            readonly property int size: 28
            readonly property int lineHeight: 36
            readonly property int weight: Font.Normal
            readonly property real letterSpacing: 0
        }
        readonly property QtObject headlineSmall: QtObject {
            readonly property int size: 24
            readonly property int lineHeight: 32
            readonly property int weight: Font.Normal
            readonly property real letterSpacing: 0
        }

        // Title styles
        readonly property QtObject titleLarge: QtObject {
            readonly property int size: 22
            readonly property int lineHeight: 28
            readonly property int weight: Font.Normal
            readonly property real letterSpacing: 0
        }
        readonly property QtObject titleMedium: QtObject {
            readonly property int size: 16
            readonly property int lineHeight: 24
            readonly property int weight: Font.Medium
            readonly property real letterSpacing: 0.15
        }
        readonly property QtObject titleSmall: QtObject {
            readonly property int size: 14
            readonly property int lineHeight: 20
            readonly property int weight: Font.Medium
            readonly property real letterSpacing: 0.1
        }

        // Label styles
        readonly property QtObject labelLarge: QtObject {
            readonly property int size: 14
            readonly property int lineHeight: 20
            readonly property int weight: Font.Medium
            readonly property real letterSpacing: 0.1
        }
        readonly property QtObject labelMedium: QtObject {
            readonly property int size: 12
            readonly property int lineHeight: 16
            readonly property int weight: Font.Medium
            readonly property real letterSpacing: 0.5
        }
        readonly property QtObject labelSmall: QtObject {
            readonly property int size: 11
            readonly property int lineHeight: 16
            readonly property int weight: Font.Medium
            readonly property real letterSpacing: 0.5
        }

        // Body styles
        readonly property QtObject bodyLarge: QtObject {
            readonly property int size: 16
            readonly property int lineHeight: 24
            readonly property int weight: Font.Normal
            readonly property real letterSpacing: 0.15
        }
        readonly property QtObject bodyMedium: QtObject {
            readonly property int size: 14
            readonly property int lineHeight: 20
            readonly property int weight: Font.Normal
            readonly property real letterSpacing: 0.25
        }
        readonly property QtObject bodySmall: QtObject {
            readonly property int size: 12
            readonly property int lineHeight: 16
            readonly property int weight: Font.Normal
            readonly property real letterSpacing: 0.4
        }
    }

    // Material Motion specification
    readonly property QtObject motion: QtObject {
        // Duration tokens (milliseconds)
        readonly property QtObject duration: QtObject {
            readonly property int short1: 50
            readonly property int short2: 100
            readonly property int short3: 150
            readonly property int short4: 200
            readonly property int medium1: 250
            readonly property int medium2: 300
            readonly property int medium3: 350
            readonly property int medium4: 400
            readonly property int long1: 450
            readonly property int long2: 500
            readonly property int long3: 550
            readonly property int long4: 600
            readonly property int extraLong1: 700
            readonly property int extraLong2: 800
            readonly property int extraLong3: 900
            readonly property int extraLong4: 1000
        }

        // Easing curves (Material Design 3)
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
