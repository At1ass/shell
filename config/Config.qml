pragma Singleton

import Quickshell
import QtQuick

Singleton {
    id: config

    // Material Design 3 Colors (следует официальной спецификации)
    property QtObject colors: QtObject {
        // Primary colors
        property color primary: "#D0BCFF"
        property color primaryText: "#371E73"
        property color primaryContainer: "#4F378B"
        property color primaryContainerText: "#EADDFF"

        // Secondary colors
        property color secondary: "#CCC2DC"
        property color secondaryText: "#332D41"
        property color secondaryContainer: "#4A4458"
        property color secondaryContainerText: "#E8DEF8"

        // Tertiary colors
        property color tertiary: "#EFB8C8"
        property color tertiaryText: "#492532"
        property color tertiaryContainer: "#633B48"
        property color tertiaryContainerText: "#FFD8E4"

        // Error colors
        property color error: "#F2B8B5"
        property color errorText: "#601410"
        property color errorContainer: "#8C1D18"
        property color errorContainerText: "#F9DEDC"

        // Neutral colors
        property color background: "#10131A"
        property color backgroundText: "#E6E0E9"
        property color surface: "#10131A"
        property color surfaceText: "#E6E0E9"
        property color surfaceVariant: "#49454F"
        property color surfaceVariantText: "#CAC4D0"
        property color outline: "#938F99"
        property color outlineVariant: "#49454F"

        // Surface container variants (новые в Material Design 3)
        property color surfaceDim: "#10131A"
        property color surfaceBright: "#36394A"
        property color surfaceContainerLowest: "#0B0E17"
        property color surfaceContainerLow: "#191C24"
        property color surfaceContainer: "#1D2027"
        property color surfaceContainerHigh: "#272A32"
        property color surfaceContainerHighest: "#32353D"

        // Inverse colors
        property color inverseSurface: "#E6E0E9"
        property color inverseSurfaceText: "#322F37"
        property color inversePrimary: "#6750A4"

        // Legacy compatibility aliases
        property color textPrimary: surfaceText
        property color textSecondary: surfaceVariantText
        property color textOnPrimary: primaryText
        property color textOnPrimaryContainer: primaryContainerText
    }

    // Material Design 3 spacing (8px grid system)
    property QtObject spacing: QtObject {
        property int none: 0
        property int extraSmall: 4
        property int small: 8
        property int medium: 16
        property int large: 24
        property int extraLarge: 32
        property int huge: 40
        property int extraHuge: 48
    }

    // Material Design 3 shape/radius tokens
    property QtObject shape: QtObject {
        property int none: 0
        property int extraSmall: 4
        property int small: 8
        property int medium: 12
        property int large: 16
        property int extraLarge: 28
        property int full: 999
    }

    // Legacy radius alias for compatibility
    property QtObject radius: shape

    // Bar configuration
    property QtObject bar: QtObject {
        property string position: "top"
        property int width: 56
        property int height: 44  // Более компактный размер
        property color background: config.colors.surfaceContainer
        property real backgroundOpacity: 0.95
        property int cornerRadius: config.shape.extraLarge
        property int margin: config.spacing.medium

        property var entries: [
            {"id": "workspaces", "enabled": true},
            {"id": "spacer", "enabled": true},
            {"id": "tray", "enabled": true},
            {"id": "system", "enabled": true},
            {"id": "clock", "enabled": true}
        ]
    }

    // Typography following Material Design 3
    property QtObject typography: QtObject {
        property string fontFamily: "Roboto"

        // Display styles
        property QtObject displayLarge: QtObject {
            property int size: 57
            property int lineHeight: 64
            property int weight: Font.Light
            property real letterSpacing: -0.25
        }
        property QtObject displayMedium: QtObject {
            property int size: 45
            property int lineHeight: 52
            property int weight: Font.Light
            property real letterSpacing: 0
        }
        property QtObject displaySmall: QtObject {
            property int size: 36
            property int lineHeight: 44
            property int weight: Font.Normal
            property real letterSpacing: 0
        }

        // Headline styles
        property QtObject headlineLarge: QtObject {
            property int size: 32
            property int lineHeight: 40
            property int weight: Font.Normal
            property real letterSpacing: 0
        }
        property QtObject headlineMedium: QtObject {
            property int size: 28
            property int lineHeight: 36
            property int weight: Font.Normal
            property real letterSpacing: 0
        }
        property QtObject headlineSmall: QtObject {
            property int size: 24
            property int lineHeight: 32
            property int weight: Font.Normal
            property real letterSpacing: 0
        }

        // Title styles
        property QtObject titleLarge: QtObject {
            property int size: 22
            property int lineHeight: 28
            property int weight: Font.Normal
            property real letterSpacing: 0
        }
        property QtObject titleMedium: QtObject {
            property int size: 16
            property int lineHeight: 24
            property int weight: Font.Medium
            property real letterSpacing: 0.15
        }
        property QtObject titleSmall: QtObject {
            property int size: 14
            property int lineHeight: 20
            property int weight: Font.Medium
            property real letterSpacing: 0.1
        }

        // Label styles
        property QtObject labelLarge: QtObject {
            property int size: 14
            property int lineHeight: 20
            property int weight: Font.Medium
            property real letterSpacing: 0.1
        }
        property QtObject labelMedium: QtObject {
            property int size: 12
            property int lineHeight: 16
            property int weight: Font.Medium
            property real letterSpacing: 0.5
        }
        property QtObject labelSmall: QtObject {
            property int size: 11
            property int lineHeight: 16
            property int weight: Font.Medium
            property real letterSpacing: 0.5
        }

        // Body styles
        property QtObject bodyLarge: QtObject {
            property int size: 16
            property int lineHeight: 24
            property int weight: Font.Normal
            property real letterSpacing: 0.15
        }
        property QtObject bodyMedium: QtObject {
            property int size: 14
            property int lineHeight: 20
            property int weight: Font.Normal
            property real letterSpacing: 0.25
        }
        property QtObject bodySmall: QtObject {
            property int size: 12
            property int lineHeight: 16
            property int weight: Font.Normal
            property real letterSpacing: 0.4
        }
    }

    // Material Motion specification
    property QtObject motion: QtObject {
        // Duration tokens (milliseconds)
        property QtObject duration: QtObject {
            property int short1: 50
            property int short2: 100
            property int short3: 150
            property int short4: 200
            property int medium1: 250
            property int medium2: 300
            property int medium3: 350
            property int medium4: 400
            property int long1: 450
            property int long2: 500
            property int long3: 550
            property int long4: 600
            property int extraLong1: 700
            property int extraLong2: 800
            property int extraLong3: 900
            property int extraLong4: 1000
        }

        // Easing curves (Material Design 3)
        property QtObject easing: QtObject {
            property int emphasized: Easing.BezierSpline
            property var emphasizedPoints: [0.2, 0.0, 0, 1.0]
            property int standard: Easing.BezierSpline
            property var standardPoints: [0.2, 0.0, 0, 1.0]
            property int emphasizedDecelerate: Easing.BezierSpline
            property var emphasizedDeceleratePoints: [0.05, 0.7, 0.1, 1.0]
            property int emphasizedAccelerate: Easing.BezierSpline
            property var emphasizedAcceleratePoints: [0.3, 0.0, 0.8, 0.15]
        }

        // Legacy aliases for compatibility
        property int durationShort: duration.short3
        property int durationMedium: duration.medium2
        property int durationLong: duration.long2
        property int durationExtraLong: duration.extraLong1
    }

    // Legacy animations alias
    property QtObject animations: motion
}
