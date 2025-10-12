pragma Singleton

import Quickshell
import QtQuick
import Mcu 1.0
import qs.src.core.services

Singleton {
    id: config

    McuTheme {
        id: theme
        // source: Qt.alpha("#00FF00", 0) // Material Design purple
        // source: Qt.resolvedUrl("/home/at1ass/Downloads/stunning-anime-girl-with-bright-blue-eyes-7r-3440x1440.jpg")
        source: WallpaperService.currentWallpaper !== "" ? WallpaperService.currentWallpaper : Qt.alpha("#6200EE", 0)
        // source: Qt.resolvedUrl("/home/at1ass/Downloads/taro-sakamoto-3840x2160-23909.png")
        darkMode: GlobalStates.darkMode
        variant: "content" // "expressive" // "vibrant" // "content" // "tonal-spot"
        contrast: 0.0

        onColorsChanged: {
            console.log("Theme colors updated:", colors);
            console.log("Primary color:", colors.primary);
        }
    }

    property QtObject weather: QtObject {
        property int refreshMinutes: 15
        property string location: "Penza"
    }

    property QtObject colors: QtObject {
        id: c
        // Типизированные токены (добавь нужные тебе роли)
        property color primary
        property color onPrimary
        property color primaryContainer
        property color onPrimaryContainer

        property color secondary
        property color onSecondary
        property color secondaryContainer
        property color onSecondaryContainer

        property color tertiary
        property color onTertiary
        property color tertiaryContainer
        property color onTertiaryContainer

        property color error
        property color onError
        property color errorContainer
        property color onErrorContainer

        property color surface
        property color onSurface
        property color surfaceVariant
        property color onSurfaceVariant
        property color outline
        property color outlineVariant

        property color background
        property color onBackground

        property color inverseSurface
        property color inverseOnSurface
        property color inversePrimary

        property color surfaceDim
        property color surfaceBright
        property color surfaceContainerLowest
        property color surfaceContainerLow
        property color surfaceContainer
        property color surfaceContainerHigh
        property color surfaceContainerHighest

        property color primaryPaletteKeyColor
        property color secondaryPaletteKeyColor
        property color tertiaryPaletteKeyColor
        property color neutralPaletteKeyColor
        property color neutralVariantPaletteKeyColor
        property color shadow
        property color scrim
        property color surfaceTint
        property color primaryFixed
        property color primaryFixedDim
        property color onPrimaryFixed
        property color onPrimaryFixedVariant
        property color secondaryFixed
        property color secondaryFixedDim
        property color onSecondaryFixed
        property color onSecondaryFixedVariant
        property color tertiaryFixed
        property color tertiaryFixedDim
        property color onTertiaryFixed
        property color onTertiaryFixedVariant

        // Универсальное применение карты из плагина
        function apply(map, fallback) {
            fallback = fallback || {};
            for (var k in map) {
                if (c.hasOwnProperty(k)) {
                    // QML сам сконвертирует "#RRGGBB" -> color один раз
                    c[k] = map[k];
                }
            }
            // фолбэки на случай отсутствующих ключей (по желанию)
            if (!map.primary && fallback.primary)
                c.primary = fallback.primary;
        }
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

    property QtObject elevation: QtObject {
        property real level0Opacity: 0.0
        property real level1Opacity: 0.05
        property real level2Opacity: 0.08
        property real level3Opacity: 0.11
        property real level4Opacity: 0.12
        property real level5Opacity: 0.14
    }

    // Material Design 3 state layer opacity tokens
    property QtObject stateLayer: QtObject {
        property real hoverOpacity: 0.08
        property real pressedOpacity: 0.12
        property real focusOpacity: 0.12
        property real draggedOpacity: 0.16
    }

    // Material Design 3 icon size tokens
    property QtObject iconSize: QtObject {
        property int small: 16
        property int medium: 20
        property int large: 24
        property int extraLarge: 32
    }

    // Material Design 3 touch target tokens
    property QtObject touchTarget: QtObject {
        property int minimum: 48
    }

    // Material Design 3 ripple effect tokens
    property QtObject ripple: QtObject {
        property color defaultColor: config.colors.onSurface
        property real hoverOpacity: 0.08
        property real pressedOpacity: 0.12
    }

    // Legacy radius alias for compatibility
    property QtObject radius: shape

    // Bar configuration
    property QtObject bar: QtObject {
        property string position: "top"
        property int width: 56
        // property int height: 44  // Более компактный размер
        property int height: 48  // Более компактный размер
        property color background: config.colors.surfaceContainer
        property real backgroundOpacity: 0.95
        property int cornerRadius: config.shape.extraLarge
        property int margin: config.spacing.medium

        property var entries: [
            {
                "id": "workspaces",
                "enabled": true
            },
            {
                "id": "spacer",
                "enabled": true
            },
            {
                "id": "tray",
                "enabled": true
            },
            {
                "id": "system",
                "enabled": true
            },
            {
                "id": "clock",
                "enabled": true
            }
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

    property string vpnName: "nikuznetsov\(2\)"

    Component.onCompleted: {
        c.apply(theme.colors);
    }

    Connections {
        target: theme
        function onColorsChanged() {
            c.apply(theme.colors);
        }
    }
}
